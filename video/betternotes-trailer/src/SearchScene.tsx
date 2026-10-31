import React from "react";
import {
  Img,
  staticFile,
  useCurrentFrame,
  interpolate,
  Easing,
} from "remotion";
import { Stage, Top, Heading, Pointer, SceneProps, defaults } from "./Scenes";
import { theme as T } from "./theme";
const ease = Easing.bezier(0.33, 0, 0.15, 1);
const ramp = (f: number, a: number, b: number) =>
  interpolate(f, [a, b], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: ease,
  });
const keys = [
  { f: 0, x: 600, y: 150, s: 2.4 },
  { f: 66, x: 600, y: 150, s: 2.4 },
  { f: 90, x: 1000, y: 300, s: 0.82 },
  { f: 132, x: 1000, y: 300, s: 0.82 },
  { f: 158, x: 540, y: 345, s: 1.8 },
];
const camera = (f: number) => {
  let a = keys[0],
    b = keys.at(-1)!;
  for (let i = 0; i < keys.length - 1; i++) {
    if (f >= keys[i].f && f <= keys[i + 1].f) {
      a = keys[i];
      b = keys[i + 1];
      break;
    }
  }
  const t = a.f === b.f ? 1 : ramp(f, a.f, b.f);
  return {
    x: a.x + (b.x - a.x) * t,
    y: a.y + (b.y - a.y) * t,
    s: a.s + (b.s - a.s) * t,
  };
};

// Adapted from exact TypeAndFilter.tsx: close typing -> pullback -> real-slot
// result -> pointer, double ring, selected outline -> push into actual detail.
export const Search: React.FC<SceneProps> = ({
  title = defaults.search.title,
  subtitle = defaults.search.subtitle,
}) => {
  const f = useCurrentFrame();
  const cam = camera(f);
  const query = "Everyday";
  const typed =
    f < 30
      ? ""
      : query.slice(0, Math.min(query.length, Math.floor((f - 30) / 3) + 1));
  const filter = 92,
    click = 132;
  const pointerT = ramp(f, 112, 130);
  const pointer = {
    x: 1160 + (540 - 1160) * pointerT,
    y: 150 + (345 - 150) * pointerT + Math.sin(pointerT * Math.PI) * 60,
  };
  const sx = (x: number) => 140 + 820 + (x - cam.x) * cam.s,
    sy = (y: number) => 350 + 250 + (y - cam.y) * cam.s;
  const handoff = ramp(f, 158, 174);
  return (
    <Stage>
      <Top label="Finding things" />
      <Heading
        title={title.replace("\n", " ")}
        subtitle={subtitle}
        y={135}
        width={1700}
      />
      <div
        style={{
          position: "absolute",
          left: 140,
          top: 350,
          width: 1640,
          height: 500,
          overflow: "hidden",
          borderRadius: 18,
          background: T.paper,
          boxShadow: "0 24px 70px #1c1c1e18",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 820 - cam.x * cam.s,
            top: 250 - cam.y * cam.s,
            width: 1920,
            height: 1080,
            transform: `scale(${cam.s})`,
            transformOrigin: "0 0",
            opacity: 1 - handoff,
          }}
        >
          <Img
            src={staticFile("screens/library-colorful.png")}
            style={{ width: 1920, height: 1080 }}
          />
          <div
            style={{
              position: "absolute",
              left: 252,
              top: 220,
              width: 1668,
              height: 860,
              background: T.paper,
            }}
          />
          {[0, 1, 2, 3, 4, 5].map((i) => {
            const col = i % 3,
              row = Math.floor(i / 3),
              target = i === 3,
              leave = ramp(f, filter + i * 0.8, filter + i * 0.8 + 14),
              slide = ramp(f, filter, filter + 22);
            return (
              <div
                key={i}
                style={{
                  position: "absolute",
                  left: 272 + col * 546,
                  top: target ? 522 - 284 * slide : 238 + row * 284,
                  width: 532,
                  height: 270,
                  borderRadius: 12,
                  overflow: "hidden",
                  opacity: target ? 1 : 1 - leave,
                  transform: `translateY(${target ? 0 : 8 * leave}px) scale(${target ? 1 + 0.02 * Math.sin(slide * Math.PI) : 1 - 0.015 * leave})`,
                }}
              >
                <Img
                  src={staticFile("screens/library-colorful.png")}
                  style={{
                    position: "absolute",
                    width: 1920,
                    height: 1080,
                    left: -(272 + col * 546),
                    top: -(238 + row * 284),
                  }}
                />
              </div>
            );
          })}
          <div
            style={{
              position: "absolute",
              left: 310,
              top: 125,
              width: 1500,
              height: 40,
              background: "white",
              display: "flex",
              alignItems: "center",
              fontSize: 20,
              color: T.ink,
            }}
          >
            {typed}
            <span
              style={{
                width: 2,
                height: 23,
                background: T.blue,
                marginLeft: 2,
                opacity: f < 54 || Math.floor(f / 8) % 2 === 0 ? 1 : 0,
              }}
            />
          </div>
          <div
            style={{
              position: "absolute",
              left: 272,
              top: 124,
              width: 1624,
              height: 44,
              border: `2px solid ${T.blue}`,
              borderRadius: 8,
              opacity: ramp(f, 10, 24),
            }}
          />
          {f >= click ? (
            <div
              style={{
                position: "absolute",
                left: 266,
                top: 232,
                width: 544,
                height: 282,
                border: `3px solid ${T.blue}`,
                borderRadius: 18,
                boxShadow: "0 0 0 4px #005fcc18",
                opacity: ramp(f, click, click + 5),
              }}
            />
          ) : null}
          {[0, 1].map((r) => {
            const start = click + r * 3,
              t = ramp(f, start, start + 12),
              rad = 14 + (r ? 78 : 54) * t;
            return f >= start && f < start + 12 ? (
              <div
                key={r}
                style={{
                  position: "absolute",
                  left: 540 - rad,
                  top: 345 - rad,
                  width: rad * 2,
                  height: rad * 2,
                  border: `3px solid ${T.blue}`,
                  borderRadius: "50%",
                  opacity: 1 - t,
                }}
              />
            ) : null;
          })}
        </div>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "white",
            opacity: handoff,
            overflow: "hidden",
          }}
        >
          <Img
            src={staticFile("screens/reading-detail.png")}
            style={{
              position: "absolute",
              width: 5248,
              height: 2952,
              left: -20,
              top: -100,
            }}
          />
          <div
            style={{
              position: "absolute",
              right: 60,
              bottom: 45,
              fontSize: 44,
              fontWeight: 600,
              color: T.blue,
            }}
          >
            Reading list
          </div>
        </div>
      </div>
      {f > 110 && f < 153 ? (
        <div style={{ opacity: 1 - ramp(f, 144, 153) }}>
          <Pointer
            x={sx(pointer.x)}
            y={sy(pointer.y)}
            click={f >= click && f < click + 4 ? 1 : 0}
          />
        </div>
      ) : null}
    </Stage>
  );
};
