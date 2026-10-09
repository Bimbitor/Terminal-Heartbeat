"use client";

export default function Home() {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        fontFamily: "'Segoe UI', sans-serif",
        padding: "2rem",
        textAlign: "center",
      }}
    >
      <div
        style={{
          fontSize: "4rem",
          animation: "pulse 1.2s ease-in-out infinite",
        }}
      >
        ❤️
      </div>
      <h1
        style={{
          fontSize: "1.8rem",
          fontWeight: 300,
          color: "#dc1e32",
          marginTop: "1rem",
        }}
      >
        Terminal Heartbeat
      </h1>
      <p
        style={{
          fontSize: "1rem",
          color: "#888",
          maxWidth: "400px",
          lineHeight: 1.6,
          marginTop: "0.5rem",
        }}
      >
        A heartbeat that crosses the screen to reach you.
      </p>
      <style>{`
        @keyframes pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.15); }
        }
      `}</style>
    </div>
  );
}
