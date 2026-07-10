const http = require("http");
const { version } = require("./package.json");

const port = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(
    JSON.stringify({
      message: "Hello from the ECR lab container!",
      version,
      hostname: process.env.HOSTNAME || "unknown",
      servedAt: new Date().toISOString(),
    })
  );
});

server.listen(port, () => {
  console.log(`ecr-lab-app v${version} listening on port ${port}`);
});

// Containers receive SIGTERM on stop - exit cleanly.
process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
