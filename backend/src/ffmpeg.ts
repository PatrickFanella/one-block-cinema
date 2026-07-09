import { spawn } from "node:child_process";
import { mkdir, readdir } from "node:fs/promises";
import { join } from "node:path";

function run(command: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => {
      stderr = `${stderr}${chunk}`.slice(-8_000);
    });
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} exited with ${code}: ${stderr}`));
    });
  });
}

export async function extractModerationFrames(
  inputPath: string,
  outputDirectory: string,
  maximumFrames = 24,
): Promise<string[]> {
  if (!Number.isInteger(maximumFrames) || maximumFrames < 1 || maximumFrames > 24) {
    throw new Error("maximumFrames must be between 1 and 24");
  }
  await mkdir(outputDirectory, { recursive: true });
  const outputPattern = join(outputDirectory, "frame-%03d.jpg");
  await run("ffmpeg", [
    "-nostdin",
    "-hide_banner",
    "-loglevel",
    "error",
    "-i",
    inputPath,
    "-vf",
    "select='eq(n,0)+gt(scene,0.35)',scale='min(1280,iw)':-2",
    "-fps_mode",
    "vfr",
    "-frames:v",
    String(maximumFrames),
    "-q:v",
    "3",
    outputPattern,
  ]);
  return (await readdir(outputDirectory))
    .filter((name) => name.startsWith("frame-") && name.endsWith(".jpg"))
    .sort()
    .slice(0, maximumFrames)
    .map((name) => join(outputDirectory, name));
}
