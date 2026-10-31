import React from "react";
import {
  AbsoluteFill,
  Audio,
  Sequence,
  staticFile,
  useCurrentFrame,
  interpolate,
} from "remotion";
import {
  Intro,
  Design,
  Write,
  Visual,
  Search,
  Offline,
  Extras,
  More,
  Outro,
} from "./Scenes";
import { SHOTS, CAPTIONS, SFX, TOTAL } from "./timeline";
import { theme as T } from "./theme";
export const COMPONENTS = [
  Intro,
  Design,
  Write,
  Visual,
  Search,
  Offline,
  Extras,
  More,
  Outro,
];
export const Caption: React.FC<{ text: string }> = ({ text }) => (
  <AbsoluteFill
    style={{
      justifyContent: "flex-end",
      alignItems: "center",
      paddingBottom: 48,
      fontFamily: T.font,
      pointerEvents: "none",
    }}
  >
    <div
      style={{
        fontSize: 60,
        fontWeight: 500,
        lineHeight: 1.2,
        background: T.ink,
        color: "white",
        padding: "16px 30px 20px",
        borderRadius: 10,
        maxWidth: 1700,
        textAlign: "center",
      }}
    >
      {text}
    </div>
  </AbsoluteFill>
);
export const Music: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <Audio
      src={staticFile("audio/music.mp3")}
      volume={interpolate(
        frame,
        [0, 30, TOTAL - 70, TOTAL],
        [0, 0.075, 0.075, 0],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
      )}
    />
  );
};
export const Main: React.FC<{ bgm?: boolean }> = ({ bgm = true }) => (
  <AbsoluteFill style={{ background: T.paper }}>
    {SHOTS.map((s, i) => {
      const Component = COMPONENTS[i];
      return (
        <Sequence
          key={s.id}
          name={s.id}
          from={s.from}
          durationInFrames={s.duration}
        >
          <Component duration={s.duration} />
        </Sequence>
      );
    })}
    {CAPTIONS.map((c) => (
      <Sequence
        key={c.from}
        name="Explanation"
        from={c.from}
        durationInFrames={c.duration}
      >
        <Caption text={c.text} />
      </Sequence>
    ))}
    {SFX.map((s, i) => (
      <Sequence
        key={i}
        name="Sound effect"
        from={s.from}
        durationInFrames={s.duration}
      >
        <Audio src={staticFile(s.src)} volume={s.volume} />
      </Sequence>
    ))}
    {bgm ? <Music /> : null}
  </AbsoluteFill>
);
