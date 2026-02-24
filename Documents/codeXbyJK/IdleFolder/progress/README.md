# Agent Team Progress

## Files
- `agent-progress.json`: 팀원별 작업 상태 입력
- `latest-report.md`: 최근 생성된 리포트

## Update Flow
1. `agent-progress.json`에 상태 업데이트
2. 드라이런으로 출력 확인
   - `node IdleFolder/scripts/notion_progress_report.js --dry-run`
3. Notion 업로드
   - `NOTION_API_TOKEN=... NOTION_PROGRESS_PAGE_TITLE=Progress node IdleFolder/scripts/notion_progress_report.js`

## Optional Env
- `NOTION_API_TOKEN`: Notion internal integration token
- `NOTION_PROGRESS_PAGE_TITLE`: 기본값 `Progress`
- `NOTION_PARENT_PAGE_ID`: Progress 페이지가 없을 때 생성할 부모 페이지 ID
