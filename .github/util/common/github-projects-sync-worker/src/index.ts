// ===================================================================
// GitHub Projects Sync Worker
// ===================================================================
//
// GitHub Projects의 Status 변경을 감지하여 Issue Label을 자동 동기화합니다.
//
// 동작 방식:
// 1. GitHub Webhook (projects_v2_item) 이벤트 수신
// 2. Webhook Secret 검증
// 3. GraphQL API로 현재 Status 조회
// 4. Issue Label 동기화 (기존 Status Label 제거 → 새 Label 추가)
//
// ===================================================================

export interface Env {
  // Secrets (wrangler secret put으로 설정)
  GITHUB_TOKEN: string;
  WEBHOOK_SECRET: string;

  // Variables (wrangler.toml에서 설정)
  PROJECT_NUMBER: string;
  STATUS_FIELD: string;
  STATUS_LABELS: string;
  ORG_NAME: string;
}

interface WebhookPayload {
  action: string;
  projects_v2_item?: {
    id: number;
    node_id: string;
    project_node_id: string;
    content_node_id?: string;
    content_type?: string;
  };
  changes?: {
    field_value?: {
      field_node_id: string;
      field_type: string;
    };
  };
  sender?: {
    login: string;
    type: string;
  };
}

interface GraphQLResponse {
  data?: {
    node?: {
      content?: {
        __typename: string;
        number?: number;
        title?: string;
        repository?: {
          name: string;
          owner: {
            login: string;
          };
        };
        labels?: {
          nodes: Array<{ name: string }>;
        };
      };
      fieldValueByName?: {
        name?: string;
      };
    };
  };
  errors?: Array<{ message: string }>;
}

// ===================================================================
// Webhook Secret 검증 (HMAC-SHA256)
// ===================================================================
async function verifySignature(
  body: string,
  signature: string | null,
  secret: string
): Promise<boolean> {
  if (!signature) {
    console.log('❌ Signature header missing');
    return false;
  }

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signatureBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const hashArray = Array.from(new Uint8Array(signatureBuffer));
  const hashHex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
  const expectedSignature = `sha256=${hashHex}`;

  // Timing-safe comparison
  if (signature.length !== expectedSignature.length) {
    return false;
  }

  let result = 0;
  for (let i = 0; i < signature.length; i++) {
    result |= signature.charCodeAt(i) ^ expectedSignature.charCodeAt(i);
  }

  return result === 0;
}

// ===================================================================
// GraphQL API 호출
// ===================================================================
async function graphqlQuery(
  query: string,
  variables: Record<string, unknown>,
  token: string
): Promise<GraphQLResponse> {
  const response = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'GitHub-Projects-Sync-Worker',
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!response.ok) {
    throw new Error(`GraphQL request failed: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

// ===================================================================
// Issue Label 업데이트 (REST API)
// ===================================================================
async function removeLabel(
  owner: string,
  repo: string,
  issueNumber: number,
  label: string,
  token: string
): Promise<void> {
  const url = `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels/${encodeURIComponent(label)}`;

  const response = await fetch(url, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${token}`,
      'User-Agent': 'GitHub-Projects-Sync-Worker',
      Accept: 'application/vnd.github.v3+json',
    },
  });

  if (response.ok || response.status === 404) {
    console.log(`  ✅ Label "${label}" 제거됨 (또는 이미 없음)`);
  } else {
    console.warn(`  ⚠️ Label "${label}" 제거 실패: ${response.status}`);
  }
}

async function addLabel(
  owner: string,
  repo: string,
  issueNumber: number,
  label: string,
  token: string
): Promise<void> {
  const url = `https://api.github.com/repos/${owner}/${repo}/issues/${issueNumber}/labels`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'User-Agent': 'GitHub-Projects-Sync-Worker',
      Accept: 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ labels: [label] }),
  });

  if (response.ok) {
    console.log(`  ✅ Label "${label}" 추가됨`);
  } else {
    const errorText = await response.text();
    console.error(`  ❌ Label "${label}" 추가 실패: ${response.status} - ${errorText}`);
    throw new Error(`Failed to add label: ${response.status}`);
  }
}

// ===================================================================
// 메인 동기화 로직
// ===================================================================
async function syncLabelFromStatus(payload: WebhookPayload, env: Env): Promise<void> {
  const itemNodeId = payload.projects_v2_item?.node_id;

  if (!itemNodeId) {
    console.log('⚠️ Item node_id not found');
    return;
  }

  console.log(`📌 Processing item: ${itemNodeId}`);

  // 1. GraphQL로 Item 정보 조회
  const query = `
    query($itemId: ID!, $statusField: String!) {
      node(id: $itemId) {
        ... on ProjectV2Item {
          content {
            __typename
            ... on Issue {
              number
              title
              repository {
                name
                owner {
                  login
                }
              }
              labels(first: 20) {
                nodes {
                  name
                }
              }
            }
            ... on PullRequest {
              number
              title
            }
          }
          fieldValueByName(name: $statusField) {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
            }
          }
        }
      }
    }
  `;

  const result = await graphqlQuery(
    query,
    { itemId: itemNodeId, statusField: env.STATUS_FIELD },
    env.GITHUB_TOKEN
  );

  if (result.errors) {
    console.error('❌ GraphQL errors:', result.errors);
    throw new Error(result.errors[0].message);
  }

  const content = result.data?.node?.content;
  const newStatus = result.data?.node?.fieldValueByName?.name;

  // 2. Issue가 아니면 스킵
  if (!content || content.__typename !== 'Issue') {
    console.log(`ℹ️ Skipping: Not an Issue (type: ${content?.__typename || 'unknown'})`);
    return;
  }

  if (!content.repository || !content.number) {
    console.log('⚠️ Issue repository info not found');
    return;
  }

  const owner = content.repository.owner.login;
  const repo = content.repository.name;
  const issueNumber = content.number;
  const currentLabels = content.labels?.nodes.map((l) => l.name) || [];

  console.log(`📌 Issue: ${owner}/${repo}#${issueNumber}`);
  console.log(`📌 Current Labels: ${currentLabels.join(', ') || '(none)'}`);
  console.log(`📌 New Status: "${newStatus}"`);

  if (!newStatus) {
    console.log('⚠️ Status value not found');
    return;
  }

  // 3. Status Labels 파싱
  let statusLabels: string[];
  try {
    statusLabels = JSON.parse(env.STATUS_LABELS);
  } catch {
    console.error('❌ Failed to parse STATUS_LABELS');
    statusLabels = ['작업 전', '작업 중', '확인 대기', '피드백', '작업 완료', '취소'];
  }

  // 4. 새 Status가 관리 대상인지 확인
  if (!statusLabels.includes(newStatus)) {
    console.log(`⚠️ "${newStatus}" is not a managed status label`);
    return;
  }

  // 5. 이미 동일한 Label이 있는지 확인 (무한 루프 방지)
  if (currentLabels.includes(newStatus)) {
    console.log(`✅ Label "${newStatus}" already exists. No sync needed.`);
    return;
  }

  // 6. 기존 Status Label 제거
  const labelsToRemove = currentLabels.filter(
    (label) => statusLabels.includes(label) && label !== newStatus
  );

  console.log(`🗑️ Labels to remove: ${labelsToRemove.join(', ') || '(none)'}`);

  for (const label of labelsToRemove) {
    await removeLabel(owner, repo, issueNumber, label, env.GITHUB_TOKEN);
  }

  // 7. 새 Status Label 추가
  console.log(`➕ Adding label: "${newStatus}"`);
  await addLabel(owner, repo, issueNumber, newStatus, env.GITHUB_TOKEN);

  console.log('🎉 Label sync completed!');
}

// ===================================================================
// Worker Entry Point
// ===================================================================
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🔄 GitHub Projects Sync Worker');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 1. POST 요청만 처리
    if (request.method !== 'POST') {
      console.log(`⚠️ Method not allowed: ${request.method}`);
      return new Response('Method not allowed', { status: 405 });
    }

    // 2. Body 읽기
    const body = await request.text();

    // 3. Webhook Secret 검증
    const signature = request.headers.get('X-Hub-Signature-256');

    if (!(await verifySignature(body, signature, env.WEBHOOK_SECRET))) {
      console.log('❌ Invalid webhook signature');
      return new Response('Invalid signature', { status: 401 });
    }

    console.log('✅ Webhook signature verified');

    // 4. 이벤트 타입 확인
    const event = request.headers.get('X-GitHub-Event');
    console.log(`📌 Event type: ${event}`);

    if (event === 'ping') {
      console.log('🏓 Ping event received');
      return new Response('Pong', { status: 200 });
    }

    if (event !== 'projects_v2_item') {
      console.log(`ℹ️ Ignoring event: ${event}`);
      return new Response('Ignored event', { status: 200 });
    }

    // 5. Payload 파싱
    let payload: WebhookPayload;
    try {
      payload = JSON.parse(body);
    } catch {
      console.error('❌ Failed to parse JSON body');
      return new Response('Invalid JSON', { status: 400 });
    }

    console.log(`📌 Action: ${payload.action}`);

    // 6. edited 액션만 처리 (Status 변경)
    if (payload.action !== 'edited') {
      console.log(`ℹ️ Ignoring action: ${payload.action}`);
      return new Response('Ignored action', { status: 200 });
    }

    // 7. Label 동기화 실행
    try {
      await syncLabelFromStatus(payload, env);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return new Response('OK', { status: 200 });
    } catch (error) {
      console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.error('❌ Error:', error);
      console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return new Response('Internal error', { status: 500 });
    }
  },
};
