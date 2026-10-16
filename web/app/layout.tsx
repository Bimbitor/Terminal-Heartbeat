import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terminal Heartbeat",
  description: "A heartbeat that crosses the screen to reach you.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es">
      <body style={{ margin: 0, backgroundColor: "#0a0a0a", color: "#e6e6e6" }}>
        {children}
      </body>
    </html>
  );
}
