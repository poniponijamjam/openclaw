#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { Client } = require("@notionhq/client");

const STATUS_EMOJI = {
  done: "✅",
  in_progress: "🟡",
  todo: "⬜"
};

function usage() {
  console.log("Usage: node IdleFolder/scripts/notion_progress_report.js [--dry-run]");
}

function readReport() {
  const reportPath = path.resolve(process.cwd(), "IdleFolder/progress/agent-progress.json");
  const raw = fs.readFileSync(reportPath, "utf8");
  return JSON.parse(raw);
}

function normalizeTitleProperty(page) {
  const props = page.properties || {};
  for (const key of Object.keys(props)) {
    if (props[key]?.type === "title") {
      return key;
    }
  }
  return null;
}

function getPageTitle(page) {
  const props = page.properties || {};
  const titleProp = normalizeTitleProperty(page);
  if (!titleProp) return "Untitled";
  const titleArr = props[titleProp]?.title || [];
  return titleArr.map((t) => t.plain_text).join("") || "Untitled";
}

function buildBlocks(report) {
  const now = new Date();
  const ts = now.toISOString().replace("T", " ").slice(0, 16);
  const lines = [];

  lines.push(`Progress update (${ts})`);
  lines.push("");

  for (const member of report.members) {
    const emoji = STATUS_EMOJI[member.status] || "•";
    lines.push(`${emoji} ${member.name} [${member.role}] ${member.progress}%`);
    for (const task of member.tasks) {
      const tEmoji = STATUS_EMOJI[task.status] || "•";
      lines.push(`  ${tEmoji} ${task.title}`);
    }
    if (member.note) {
      lines.push(`  Note: ${member.note}`);
    }
    lines.push("");
  }

  if (report.nextActions && report.nextActions.length) {
    lines.push("Next Actions");
    for (const action of report.nextActions) {
      lines.push(`- ${action}`);
    }
  }

  return lines;
}

async function findPageByTitle(notion, title) {
  const response = await notion.search({
    query: title,
    filter: { value: "page", property: "object" }
  });

  for (const page of response.results) {
    if (getPageTitle(page) === title) {
      return page;
    }
  }
  return null;
}

async function createProgressPageIfMissing(notion, parentPageId, title) {
  const created = await notion.pages.create({
    parent: { page_id: parentPageId },
    properties: {
      title: {
        title: [{ text: { content: title } }]
      }
    }
  });
  return created;
}

async function appendReportBlocks(notion, pageId, lines) {
  const children = [];

  children.push({
    object: "block",
    type: "heading_3",
    heading_3: {
      rich_text: [{ type: "text", text: { content: "Agent Team Progress" } }]
    }
  });

  for (const line of lines) {
    if (line.startsWith("- ")) {
      children.push({
        object: "block",
        type: "bulleted_list_item",
        bulleted_list_item: {
          rich_text: [{ type: "text", text: { content: line.slice(2) } }]
        }
      });
      continue;
    }

    if (line.trim() === "") {
      children.push({
        object: "block",
        type: "paragraph",
        paragraph: { rich_text: [] }
      });
      continue;
    }

    children.push({
      object: "block",
      type: "paragraph",
      paragraph: {
        rich_text: [{ type: "text", text: { content: line } }]
      }
    });
  }

  for (let i = 0; i < children.length; i += 90) {
    await notion.blocks.children.append({
      block_id: pageId,
      children: children.slice(i, i + 90)
    });
  }
}

function printLocalSummary(report, lines) {
  const outPath = path.resolve(process.cwd(), "IdleFolder/progress/latest-report.md");
  const md = [`# ${report.reportTitle}`, "", ...lines].join("\n");
  fs.writeFileSync(outPath, md, "utf8");

  console.log("==== Agent Team Progress ====");
  console.log(md);
  console.log(`\nSaved local report: ${outPath}`);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes("-h") || args.includes("--help")) {
    usage();
    process.exit(0);
  }

  const dryRun = args.includes("--dry-run");
  const report = readReport();
  const lines = buildBlocks(report);
  printLocalSummary(report, lines);

  if (dryRun) {
    console.log("\nDry run mode: skipping Notion update.");
    return;
  }

  const token = process.env.NOTION_API_TOKEN;
  if (!token) {
    console.error("NOTION_API_TOKEN is not set.");
    process.exit(1);
  }

  const notion = new Client({ auth: token });

  const progressTitle = process.env.NOTION_PROGRESS_PAGE_TITLE || "Progress";
  let progressPage = await findPageByTitle(notion, progressTitle);

  if (!progressPage) {
    const parentPageId = process.env.NOTION_PARENT_PAGE_ID;
    if (!parentPageId) {
      console.error("Progress page not found and NOTION_PARENT_PAGE_ID is not set.");
      process.exit(1);
    }
    progressPage = await createProgressPageIfMissing(notion, parentPageId, progressTitle);
    console.log(`Created Progress page: ${progressPage.id}`);
  }

  await appendReportBlocks(notion, progressPage.id, lines);
  console.log(`Updated Notion Progress page: ${progressPage.id}`);
}

main().catch((err) => {
  console.error("Failed to update progress:", err.message);
  process.exit(1);
});
