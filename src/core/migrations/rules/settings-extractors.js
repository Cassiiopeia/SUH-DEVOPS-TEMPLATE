// 설정 이관기 (#470 확장, #478) — 구 워크플로우의 커스텀 설정을 무해화 전에 version.yml로 이관.
// 원칙: 기본값과 다른 값만 이관 / issue_helper 섹션이 이미 있으면 불변(신형 우선·멱등)
//       / version.yml 없으면 skip / 실패해도 무해화를 막지 않는다(호출부에서 try-catch).
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// 구 MODULE 워크플로우 배포본의 with: 기본값 — 이 값 그대로면 사용자 커스텀이 아니다
const OLD_DEFAULTS = {
  branch_prefix: "",
  max_branch_length: "100",
  commit_template: "${issueTitle} : feat : {변경 사항에 대한 설명} ${issueUrl}",
  comment_marker: "<!-- 이 댓글은 SUH-ISSUE-HELPER 에 의해 자동으로 생성되었습니다. - https://github.com/Cassiiopeia/github-issue-helper -->",
};

const KEYS = Object.keys(OLD_DEFAULTS);

function unquote(v) { return v.trim().replace(/^["']|["']$/g, ""); }

function parseWithValues(content) {
  const out = {};
  for (const key of KEYS) {
    const m = content.match(new RegExp(`^\\s*${key}:\\s*(.+)$`, "m"));
    if (m) out[key] = unquote(m[1].replace(/\s+#.*$/, ""));
  }
  return out;
}

// version.yml에 issue_helper 블록 삽입. 계층(metadata/template/options)이 없으면 만든다.
function insertIssueHelperBlock(vyText, carried) {
  const lines = Object.entries(carried)
    .map(([k, v]) => `        ${k}: "${v.replace(/"/g, '\\"')}"`);
  const block = ["      issue_helper:", ...lines].join("\n");

  if (/^\s{4}options:\s*$/m.test(vyText))
    return vyText.replace(/^(\s{4}options:\s*)$/m, `$1\n${block}`);
  if (/^\s{2}template:\s*$/m.test(vyText))
    return vyText.replace(/^(\s{2}template:\s*)$/m, `$1\n    options:\n${block}`);
  if (/^metadata:\s*$/m.test(vyText))
    return vyText.replace(/^(metadata:\s*)$/m, `$1\n  template:\n    options:\n${block}`);
  return `${vyText.replace(/\n*$/, "\n")}metadata:\n  template:\n    options:\n${block}\n`;
}

// 구 SUH-ISSUE-HELPER-MODULE의 with: → options.issue_helper 이관. 반환: { carried: [키...] }
export function extractIssueHelperModule(targetRoot, entry) {
  const wf = join(targetRoot, ".github", "workflows", entry.file);
  const vy = join(targetRoot, "version.yml");
  if (!existsSync(wf) || !existsSync(vy)) return { carried: [] };

  const vyText = readFileSync(vy, "utf8");
  if (/^\s*issue_helper:/m.test(vyText)) return { carried: [] }; // 신형 설정 우선

  const vals = parseWithValues(readFileSync(wf, "utf8"));
  const carried = {};
  for (const [k, v] of Object.entries(vals)) {
    if (v !== OLD_DEFAULTS[k]) carried[k] = v; // 기본값과 다른 것만
  }
  if (Object.keys(carried).length === 0) return { carried: [] };

  writeFileSync(vy, insertIssueHelperBlock(vyText, carried));
  return { carried: Object.keys(carried) };
}

export const EXTRACTORS = {
  "suh-issue-helper-module": extractIssueHelperModule,
};
