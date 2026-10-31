import React from "react";
import {
  AbsoluteFill,
  Img,
  staticFile,
  useCurrentFrame,
  interpolate,
  Easing,
} from "remotion";
import { theme as T } from "./theme";
import { PageCam } from "./PageCam";

const opt = {
  extrapolateLeft: "clamp",
  extrapolateRight: "clamp",
  easing: Easing.bezier(0.22, 1, 0.36, 1),
} as const;
const at = (f: number, a: number, b: number, x = 0, y = 1) =>
  interpolate(f, [a, b], [x, y], opt);
export type SceneProps = {
  title?: string;
  subtitle?: string;
  accent?: string;
  duration?: number;
};
export const defaults = {
  intro: {
    title: "BetterNotes",
    subtitle: "A little room for\nyour next big idea.",
  },
  design: { title: "A clear place to think.", subtitle: "Paper and Graphite" },
  write: {
    title: "Turn a thought\ninto a plan.",
    subtitle: "Rich text. Room to write.",
  },
  visual: {
    title: "Some ideas\nneed a picture.",
    subtitle: "Images and built-in drawing",
  },
  search: {
    title: "Useful notes.\nEasy to find.",
    subtitle: "Search, tags, and favorites",
  },
  offline: {
    title: "Your ideas,\nclose at hand.",
    subtitle: "How local-first notes work",
  },
  extras: {
    title: "The details\nare taken care of.",
    subtitle: "A few more reasons to keep it close",
  },
  more: { title: "Made for\nthe everyday.", subtitle: "And there’s more" },
  outro: { title: "BetterNotes", subtitle: "Make room for your next idea." },
};

export const Stage: React.FC<{ children: React.ReactNode; dark?: boolean }> = ({
  children,
  dark = false,
}) => (
  <AbsoluteFill
    style={{
      background: dark ? T.dark : T.paper,
      color: dark ? T.paper : T.ink,
      fontFamily: T.font,
      overflow: "hidden",
    }}
  >
    {children}
  </AbsoluteFill>
);
export const Top: React.FC<{ label: string; dark?: boolean }> = ({
  label,
  dark,
}) => (
  <div
    style={{
      position: "absolute",
      left: 96,
      top: 58,
      right: 96,
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      fontSize: 28,
      color: dark ? "#ADB0B8" : T.muted,
    }}
  >
    <span style={{ fontWeight: 600 }}>BetterNotes</span>
    <span>{label}</span>
  </div>
);
export const Heading: React.FC<{
  title: string;
  subtitle: string;
  dark?: boolean;
  x?: number;
  y?: number;
  width?: number;
}> = ({ title, subtitle, dark = false, x = 96, y = 174, width = 650 }) => {
  const f = useCurrentFrame();
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width,
        opacity: at(f, 4, 30),
        transform: `translateY(${at(f, 4, 36, 28, 0)}px)`,
      }}
    >
      <div
        style={{
          fontSize: 44,
          fontWeight: 600,
          color: dark ? "#66A8FF" : T.blue,
          marginBottom: 24,
        }}
      >
        {subtitle}
      </div>
      <div
        style={{
          fontSize: 86,
          lineHeight: 1.08,
          letterSpacing: -3,
          fontWeight: 650,
          whiteSpace: "pre-line",
        }}
      >
        {title}
      </div>
    </div>
  );
};
const Screen: React.FC<{
  src: string;
  x: number;
  y: number;
  w: number;
  h: number;
  radius?: number;
}> = ({ src, x, y, w, h, radius = 18 }) => (
  <div
    style={{
      position: "absolute",
      left: x,
      top: y,
      width: w,
      height: h,
      overflow: "hidden",
      borderRadius: radius,
      boxShadow: "0 24px 70px rgba(28,28,30,.12)",
      background: "white",
    }}
  >
    <Img
      src={staticFile(`screens/${src}.png`)}
      style={{
        width: "100%",
        height: "100%",
        objectFit: "cover",
        display: "block",
      }}
    />
  </div>
);
const Cut: React.FC<{
  src: string;
  x: number;
  y: number;
  w: number;
  h: number;
  crop: { x: number; y: number; w: number; h: number };
  scale?: number;
}> = ({ src, x, y, w, h, crop, scale }) => {
  const s = scale ?? w / crop.w;
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: w,
        height: h,
        overflow: "hidden",
        borderRadius: 16,
        background: "white",
        boxShadow: "0 22px 70px rgba(28,28,30,.10)",
      }}
    >
      <Img
        src={staticFile(`screens/${src}.png`)}
        style={{
          position: "absolute",
          width: 1920 * s,
          height: 1080 * s,
          maxWidth: "none",
          left: -crop.x * s,
          top: -crop.y * s,
        }}
      />
    </div>
  );
};
export const Pointer: React.FC<{ x: number; y: number; click?: number }> = ({
  x,
  y,
  click = 0,
}) => (
  <>
    <svg
      width="46"
      height="46"
      viewBox="0 0 28 28"
      style={{
        position: "absolute",
        left: x,
        top: y,
        filter: "drop-shadow(0 3px 4px #0004)",
        transform: `scale(${1 - 0.16 * click})`,
        transformOrigin: "2px 1px",
      }}
    >
      <path
        d="M2 1 L2 23 L8 17.5 L11.5 25 L15.5 23.2 L12 15.8 L20 15 Z"
        fill="#17181c"
        stroke="white"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
    </svg>
  </>
);

export const Intro: React.FC<SceneProps> = ({
  title = defaults.intro.title,
  subtitle = defaults.intro.subtitle,
}) => {
  const f = useCurrentFrame();
  return (
    <Stage>
      <div
        style={{
          position: "absolute",
          left: 112,
          top: 218,
          display: "flex",
          alignItems: "center",
          gap: 22,
          opacity: at(f, 0, 32),
        }}
      >
        <Img src={staticFile("logo.png")} style={{ width: 88, height: 88 }} />
        <span style={{ fontSize: 58, fontWeight: 650, letterSpacing: -2 }}>
          {title}
        </span>
      </div>
      <div
        style={{
          position: "absolute",
          left: 112,
          top: 362,
          fontSize: 90,
          lineHeight: 1.1,
          fontWeight: 650,
          letterSpacing: -3,
          whiteSpace: "pre-line",
          opacity: at(f, 12, 44),
          transform: `translateY(${at(f, 12, 48, 35, 0)}px)`,
        }}
      >
        {subtitle}
      </div>
      <div
        style={{
          position: "absolute",
          left: 112,
          top: 662,
          fontSize: 44,
          color: T.blue,
          opacity: at(f, 40, 72),
        }}
      >
        Richer than a sticky note.
      </div>
      <div
        style={{
          position: "absolute",
          left: 1050,
          top: 178,
          width: 710,
          height: 610,
          transform: `perspective(1800px) rotateY(${at(f, 0, 96, -12, -5)}deg) translateY(${at(f, 0, 96, 70, 0)}px)`,
          opacity: at(f, 8, 40),
        }}
      >
        <Cut
          src="writing"
          x={0}
          y={0}
          w={710}
          h={610}
          crop={{ x: 0, y: 56, w: 670, h: 576 }}
        />
      </div>
    </Stage>
  );
};

export const Design: React.FC<SceneProps> = ({
  title = defaults.design.title,
  subtitle = defaults.design.subtitle,
}) => {
  const f = useCurrentFrame();
  const focus = f < 100 ? 0 : f < 175 ? 1 : 2;
  const boxes = [
    { x: 252, y: 250, w: 248, h: 500, text: "Collections", lx: 110, ly: 520 },
    { x: 500, y: 216, w: 1220, h: 170, text: "Tools", lx: 1340, ly: 170 },
    { x: 520, y: 416, w: 1180, h: 430, text: "Your notes", lx: 1310, ly: 650 },
  ];
  const b = boxes[focus];
  return (
    <Stage>
      <Top label="The layout" />
      <Heading title={title} subtitle={subtitle} y={140} width={1550} />
      <div
        style={{
          position: "absolute",
          left: 248,
          top: 350,
          width: 1470,
          height: 480,
          borderRadius: 18,
          overflow: "hidden",
          boxShadow: "0 22px 70px #1c1c1e18",
        }}
      >
        <PageCam
          src="screens/library-colorful.png"
          pageH={1080}
          keys={[
            { frame: 0, cx: 1263.1579, cy: 710.5263, zoom: 0.76 },
            { frame: 48, cx: 1263.1579, cy: 710.5263, zoom: 0.76 },
            { frame: 140, cx: 1263.1579, cy: 710.5263, zoom: 0.76 },
            { frame: 210, cx: 1263.1579, cy: 710.5263, zoom: 0.76 },
          ]}
        />
      </div>
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 385,
          color: T.blue,
          fontSize: 44,
          fontWeight: 600,
          opacity: at(f, 32, 55),
        }}
      >
        Sidebar
      </div>
      <div
        style={{
          position: "absolute",
          left: 1320,
          top: 310,
          color: T.blue,
          fontSize: 44,
          fontWeight: 600,
          opacity: at(f, 96, 120),
        }}
      >
        One toolbar
      </div>
      <div
        style={{
          position: "absolute",
          left: 400,
          top: 860,
          color: T.muted,
          fontSize: 44,
          opacity: at(f, 152, 178),
        }}
      >
        Quiet surfaces. Blue actions. Color-coded notes.
      </div>
      <div style={{ position: "absolute", left: b.lx, top: b.ly, fontSize: 0 }}>
        {b.text}
      </div>
    </Stage>
  );
};

export const Write: React.FC<SceneProps> = ({
  title = defaults.write.title,
  subtitle = defaults.write.subtitle,
}) => {
  const f = useCurrentFrame();
  return (
    <Stage>
      <Top label="Writing" />
      <Heading title={title} subtitle={subtitle} width={630} />
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 570,
          width: 640,
          fontSize: 44,
          lineHeight: 1.55,
          color: T.muted,
        }}
      >
        Headings for structure.
        <br />
        Checklists for the next step.
        <br />
        Keep your words styled.
      </div>
      <div
        style={{
          position: "absolute",
          left: 770,
          top: 182,
          width: 1040,
          height: 658,
          transform: `translateX(${at(f, 0, 34, 80, 0)}px)`,
          opacity: at(f, 0, 30),
        }}
      >
        <Cut
          src={f < 116 ? "writing-before" : "writing-checked"}
          x={0}
          y={0}
          w={1040}
          h={530}
          crop={{ x: 0, y: 56, w: 800, h: 408 }}
        />
        <Cut
          src="formatting"
          x={0}
          y={552}
          w={1040}
          h={104}
          crop={{ x: 710, y: 990, w: 600, h: 60 }}
        />
      </div>
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 830,
          color: T.blue,
          fontSize: 44,
          fontWeight: 600,
        }}
      >
        Separate note windows on Windows
      </div>
      {f > 65 && f < 174 ? (
        <Pointer
          x={at(f, 66, 108, 1240, 820.7)}
          y={at(f, 66, 108, 620, 413.4)}
          click={f >= 114 && f < 120 ? 1 : 0}
        />
      ) : null}
    </Stage>
  );
};

export const Visual: React.FC<SceneProps> = ({
  title = defaults.visual.title,
  subtitle = defaults.visual.subtitle,
}) => {
  const f = useCurrentFrame();
  return (
    <Stage>
      <Top label="Images and ink" />
      <Heading title={title} subtitle={subtitle} width={650} />
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 590,
          width: 640,
          fontSize: 44,
          lineHeight: 1.5,
          color: T.muted,
        }}
      >
        Collect the reference.
        <br />
        Sketch the connection.
        <br />
        Keep the context with the note.
      </div>
      <div
        style={{
          position: "absolute",
          left: 790,
          top: 190,
          transform: `translateY(${at(f, 0, 40, 60, 0)}px)`,
          opacity: at(f, 0, 30),
        }}
      >
        <Cut
          src="visual-note"
          x={0}
          y={0}
          w={1010}
          h={640}
          crop={{ x: 5, y: 65, w: 1430, h: 900 }}
        />
      </div>
      <div
        style={{
          position: "absolute",
          left: 1040,
          top: 220,
          opacity: at(f, 82, 115),
          transform: `translateY(${at(f, 82, 115, 70, 0)}px)`,
        }}
      >
        <Cut
          src="drawing"
          x={0}
          y={0}
          w={670}
          h={290}
          crop={{ x: 410, y: 190, w: 1000, h: 430 }}
        />
      </div>
    </Stage>
  );
};

export { Search } from "./SearchScene";

export const Offline: React.FC<SceneProps> = ({
  title = defaults.offline.title,
  subtitle = defaults.offline.subtitle,
}) => {
  const f = useCurrentFrame();
  const steps = [
    { x: 160, label: "Write", detail: "Your note", symbol: "Aa" },
    { x: 740, label: "Save locally", detail: "On this device", symbol: "✓" },
    {
      x: 1320,
      label: "Optional sync",
      detail: "Configured account",
      symbol: "↥",
    },
  ];
  return (
    <Stage dark>
      <Top label="How it works" dark />
      <Heading
        title={title.replace("\n", " ")}
        subtitle={subtitle}
        dark
        width={1600}
        y={148}
      />
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 360,
          fontSize: 44,
          color: "#ADB0B8",
        }}
      >
        Conceptual flow
      </div>
      {steps.map((st, i) => {
        const p = at(f, 24 + i * 30, 54 + i * 30);
        return (
          <React.Fragment key={st.label}>
            <div
              style={{
                position: "absolute",
                left: st.x,
                top: 470,
                width: 430,
                height: 310,
                opacity: p,
                transform: `translateY(${(1 - p) * 36}px)`,
                borderTop: `2px solid ${i === 2 ? "#45474F" : "#66A8FF"}`,
                paddingTop: 34,
              }}
            >
              <div
                style={{
                  fontSize: 64,
                  fontWeight: 600,
                  color: i === 2 ? "#ADB0B8" : "#66A8FF",
                }}
              >
                {st.symbol}
              </div>
              <div style={{ fontSize: 46, marginTop: 32, fontWeight: 600 }}>
                {st.label}
              </div>
              <div style={{ fontSize: 44, color: "#ADB0B8", marginTop: 18 }}>
                {st.detail}
              </div>
            </div>
            {i < 2 ? (
              <div
                style={{
                  position: "absolute",
                  left: st.x + 475,
                  top: 580,
                  width: 80,
                  fontSize: 55,
                  color: "#66A8FF",
                  opacity: at(f, 58 + i * 30, 75 + i * 30),
                }}
              >
                →
              </div>
            ) : null}
          </React.Fragment>
        );
      })}
      <div
        style={{
          position: "absolute",
          left: 160,
          top: 800,
          fontSize: 44,
          color: "#ADB0B8",
          opacity: at(f, 110, 138),
        }}
      >
        Offline comes first. Cloud sync requires your Supabase and Google setup.
      </div>
    </Stage>
  );
};

export const Extras: React.FC<SceneProps> = ({
  title = defaults.extras.title,
  subtitle = defaults.extras.subtitle,
}) => {
  const f = useCurrentFrame();
  const panels = [
    {
      src: "reminder",
      title: "Remember the moment",
      detail: "Reminders",
      crop: { x: 756, y: 246, w: 408, h: 242 },
    },
    {
      src: "cleanup",
      title: "Clean up with confidence",
      detail: "Preview before applying",
      crop: { x: 636, y: 167, w: 648, h: 384 },
    },
    {
      src: "history",
      title: "Return to earlier versions",
      detail: "Version history",
      crop: { x: 726, y: 427, w: 468, h: 278 },
    },
  ];
  return (
    <Stage>
      <Top label="The useful details" />
      <Heading
        title={title.replace("\n", " ")}
        subtitle={subtitle}
        y={138}
        width={1700}
      />
      {panels.map((p, i) => (
        <div
          key={p.src}
          style={{
            position: "absolute",
            left: 100 + i * 580,
            top: 390,
            width: 540,
            opacity: at(f, 16 + i * 16, 48 + i * 16),
            transform: `translateY(${at(f, 16 + i * 16, 48 + i * 16, 40, 0)}px)`,
          }}
        >
          <div style={{ fontSize: 44, fontWeight: 600, marginBottom: 12 }}>
            {p.title}
          </div>
          <div style={{ fontSize: 44, color: T.blue, marginBottom: 22 }}>
            {p.detail}
          </div>
          <Cut src={p.src} x={0} y={144} w={540} h={320} crop={p.crop} />
        </div>
      ))}
    </Stage>
  );
};

export const More: React.FC<SceneProps> = ({
  title = defaults.more.title,
  subtitle = defaults.more.subtitle,
}) => {
  const f = useCurrentFrame();
  return (
    <Stage>
      <Top label="Built for everyday use" />
      <Heading title={title} subtitle={subtitle} y={150} width={640} />
      <div
        style={{
          position: "absolute",
          left: 100,
          top: 530,
          display: "grid",
          gap: 20,
          fontSize: 44,
          color: T.muted,
        }}
      >
        {[
          "Templates and complete ZIP backups",
          "Markdown and PDF export",
          "Windows Sticky Notes import",
          "Keyboard and accessibility support",
        ].map((text, i) => (
          <div
            key={text}
            style={{
              opacity: at(f, 24 + i * 10, 44 + i * 10),
              transform: `translateX(${at(f, 24 + i * 10, 44 + i * 10, 20, 0)}px)`,
            }}
          >
            {text}
          </div>
        ))}
      </div>
      <div style={{ opacity: at(f, 10, 40) }}>
        <Cut
          src="backups"
          x={900}
          y={200}
          w={900}
          h={620}
          crop={{ x: 675, y: 510, w: 820, h: 565 }}
        />
      </div>
    </Stage>
  );
};

export const Outro: React.FC<SceneProps> = ({
  title = defaults.outro.title,
  subtitle = defaults.outro.subtitle,
}) => {
  const f = useCurrentFrame();
  return (
    <Stage>
      <div
        style={{
          position: "absolute",
          left: 710,
          top: 220,
          display: "flex",
          alignItems: "center",
          gap: 24,
          opacity: at(f, 0, 24),
        }}
      >
        <Img src={staticFile("logo.png")} style={{ width: 110, height: 110 }} />
        <div style={{ fontSize: 74, fontWeight: 650, letterSpacing: -3 }}>
          {title}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 180,
          right: 180,
          top: 390,
          textAlign: "center",
          fontSize: 80,
          fontWeight: 600,
          letterSpacing: -2,
          opacity: at(f, 8, 32),
        }}
      >
        {subtitle}
      </div>
      <div
        style={{
          position: "absolute",
          left: 180,
          right: 180,
          top: 520,
          textAlign: "center",
          fontSize: 38,
          color: T.blue,
          opacity: at(f, 20, 44),
        }}
      >
        Write. Collect. Find. Keep.
      </div>
      {[
        { x: 100, y: 675, rot: -5, crop: { x: 272, y: 238, w: 532, h: 270 } },
        { x: 745, y: 675, rot: 0, crop: { x: 1364, y: 238, w: 532, h: 270 } },
        { x: 1390, y: 675, rot: 5, crop: { x: 1364, y: 522, w: 532, h: 270 } },
      ].map((c, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: c.x,
            top: c.y,
            opacity: at(f, 6 + i * 4, 35 + i * 4),
            transform: `translateY(${at(f, 6 + i * 4, 45 + i * 4, 130, 0)}px) rotate(${c.rot}deg)`,
          }}
        >
          <Cut src="library-colorful" x={0} y={0} w={430} h={210} crop={c.crop} />
        </div>
      ))}
    </Stage>
  );
};
