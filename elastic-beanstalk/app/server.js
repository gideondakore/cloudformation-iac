const express = require("express");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");
const { version } = require("./package.json");

const app = express();
const port = process.env.PORT || 8080;

// Connection details come from Elastic Beanstalk managed environment variables.
const tableName = process.env.TABLE_NAME;
const region = process.env.AWS_REGION || "eu-west-1";

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region }));

// Increment and return a visit counter stored in DynamoDB. Returns null
// (instead of crashing the app) when the table is unreachable so the core
// endpoints keep working even if the optional integration is down.
async function bumpVisitCount() {
  if (!tableName) return null;
  try {
    const result = await ddb.send(
      new UpdateCommand({
        TableName: tableName,
        Key: { pk: "visits" },
        UpdateExpression: "ADD visitCount :one",
        ExpressionAttributeValues: { ":one": 1 },
        ReturnValues: "UPDATED_NEW",
      })
    );
    return result.Attributes.visitCount;
  } catch (err) {
    console.error("DynamoDB error:", err.message);
    return null;
  }
}

app.get("/", async (req, res) => {
  const visits = await bumpVisitCount();
  res.json({
    message: "Deployment successful! Hello from Elastic Beanstalk.",
    version,
    dynamodb: {
      connected: visits !== null,
      table: tableName || "not configured",
      totalVisits: visits,
    },
    servedAt: new Date().toISOString(),
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok", version });
});

app.get("/version", (req, res) => {
  res.json({ version, commit: process.env.GIT_SHA || "unknown" });
});

app.listen(port, () => {
  console.log(`eb-lab-app v${version} listening on port ${port}`);
});
