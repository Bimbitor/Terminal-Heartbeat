"use client";

import { useState, useEffect, useCallback } from "react";

interface Message {
  id: string;
  text: string;
  createdAt: string;
}

interface Greeting {
  id: string;
  text: string;
}

interface Greetings {
  morning: Greeting[];
  afternoon: Greeting[];
  night: Greeting[];
}

type Period = "morning" | "afternoon" | "night";

const PERIOD_LABELS: Record<Period, string> = {
  morning: "Buenos dias",
  afternoon: "Buenas tardes",
  night: "Buenas noches",
};

const PERIOD_ICONS: Record<Period, string> = {
  morning: "🌅",
  afternoon: "☀️",
  night: "🌙",
};

const API_BASE = typeof window !== "undefined" ? window.location.origin : "";

const styles = {
  page: {
    minHeight: "100vh",
    fontFamily: "'Segoe UI', sans-serif",
    backgroundColor: "#0a0a0a",
    color: "#e6e6e6",
    padding: "2rem",
    maxWidth: "720px",
    margin: "0 auto",
  } as React.CSSProperties,
  header: {
    textAlign: "center" as const,
    marginBottom: "2rem",
  } as React.CSSProperties,
  title: {
    fontSize: "1.6rem",
    fontWeight: 300,
    color: "#dc1e32",
  } as React.CSSProperties,
  loginBox: {
    maxWidth: "320px",
    margin: "4rem auto",
    textAlign: "center" as const,
  } as React.CSSProperties,
  input: {
    width: "100%",
    padding: "0.7rem 1rem",
    backgroundColor: "#1a1a1a",
    border: "1px solid #333",
    borderRadius: "8px",
    color: "#e6e6e6",
    fontSize: "0.95rem",
    outline: "none",
    boxSizing: "border-box" as const,
  } as React.CSSProperties,
  btn: {
    padding: "0.6rem 1.2rem",
    backgroundColor: "#dc1e32",
    color: "#fff",
    border: "none",
    borderRadius: "8px",
    cursor: "pointer",
    fontSize: "0.9rem",
    fontWeight: 500,
  } as React.CSSProperties,
  btnSmall: {
    padding: "0.3rem 0.7rem",
    fontSize: "0.8rem",
    backgroundColor: "transparent",
    color: "#888",
    border: "1px solid #333",
    borderRadius: "6px",
    cursor: "pointer",
  } as React.CSSProperties,
  btnDanger: {
    padding: "0.3rem 0.7rem",
    fontSize: "0.8rem",
    backgroundColor: "transparent",
    color: "#dc1e32",
    border: "1px solid #dc1e32",
    borderRadius: "6px",
    cursor: "pointer",
  } as React.CSSProperties,
  section: {
    marginBottom: "2.5rem",
  } as React.CSSProperties,
  sectionTitle: {
    fontSize: "1.1rem",
    fontWeight: 600,
    marginBottom: "1rem",
    color: "#dc1e32",
    borderBottom: "1px solid #222",
    paddingBottom: "0.5rem",
  } as React.CSSProperties,
  item: {
    display: "flex",
    alignItems: "flex-start",
    gap: "0.75rem",
    padding: "0.6rem 0.8rem",
    backgroundColor: "#141414",
    borderRadius: "8px",
    marginBottom: "0.5rem",
  } as React.CSSProperties,
  itemText: {
    flex: 1,
    fontSize: "0.95rem",
    whiteSpace: "pre-wrap",
    wordBreak: "break-word",
  } as React.CSSProperties,
  textarea: {
    width: "100%",
    padding: "0.7rem 1rem",
    backgroundColor: "#1a1a1a",
    border: "1px solid #333",
    borderRadius: "8px",
    color: "#e6e6e6",
    fontSize: "0.95rem",
    outline: "none",
    boxSizing: "border-box" as const,
    resize: "vertical" as const,
    minHeight: "60px",
    fontFamily: "'Segoe UI', sans-serif",
    lineHeight: "1.5",
  } as React.CSSProperties,
  addRow: {
    display: "flex",
    gap: "0.5rem",
    marginTop: "0.75rem",
  } as React.CSSProperties,
  preview: {
    width: "360px",
    backgroundColor: "#121212",
    borderRadius: "16px",
    padding: "20px 24px",
    border: "1px solid rgba(220, 30, 50, 0.4)",
    margin: "1rem auto",
  } as React.CSSProperties,
  previewGreeting: {
    color: "#dc1e32",
    fontSize: "1.1rem",
    fontWeight: 700,
    marginBottom: "0.5rem",
  } as React.CSSProperties,
  previewSep: {
    height: "1px",
    backgroundColor: "rgba(220, 30, 50, 0.25)",
    margin: "0.5rem 0",
  } as React.CSSProperties,
  previewMsg: {
    color: "#e6e6e6",
    fontSize: "0.95rem",
    lineHeight: 1.5,
    whiteSpace: "pre-wrap",
    wordBreak: "break-word",
  } as React.CSSProperties,
};

export default function AdminPage() {
  const [password, setPassword] = useState("");
  const [authed, setAuthed] = useState(false);
  const [authError, setAuthError] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [greetings, setGreetings] = useState<Greetings>({
    morning: [],
    afternoon: [],
    night: [],
  });
  const [newMsg, setNewMsg] = useState("");
  const [newGreetings, setNewGreetings] = useState<Record<Period, string>>({
    morning: "",
    afternoon: "",
    night: "",
  });
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editText, setEditText] = useState("");

  const headers = useCallback(
    () => ({
      "Content-Type": "application/json",
      Authorization: `Bearer ${password}`,
    }),
    [password]
  );

  const fetchData = useCallback(async () => {
    try {
      const [msgRes, grtRes] = await Promise.all([
        fetch(`${API_BASE}/api/messages`),
        fetch(`${API_BASE}/api/greetings`),
      ]);
      const msgData = await msgRes.json();
      const grtData = await grtRes.json();
      setMessages(msgData.messages || []);
      setGreetings(
        grtData.greetings || { morning: [], afternoon: [], night: [] }
      );
    } catch {}
  }, []);

  const tryLogin = async () => {
    try {
      const res = await fetch(`${API_BASE}/api/messages`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${password}`,
        },
        body: JSON.stringify({ text: "__auth_test__" }),
      });
      if (res.status === 401) {
        setAuthError(true);
        return;
      }
      if (res.ok) {
        const data = await res.json();
        await fetch(`${API_BASE}/api/messages`, {
          method: "DELETE",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${password}`,
          },
          body: JSON.stringify({ id: data.message.id }),
        });
      }
      setAuthed(true);
      setAuthError(false);
      fetchData();
    } catch {
      setAuthError(true);
    }
  };

  useEffect(() => {
    if (authed) fetchData();
  }, [authed, fetchData]);

  const addMessage = async () => {
    if (!newMsg.trim()) return;
    await fetch(`${API_BASE}/api/messages`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ text: newMsg }),
    });
    setNewMsg("");
    fetchData();
  };

  const deleteMessage = async (id: string) => {
    await fetch(`${API_BASE}/api/messages`, {
      method: "DELETE",
      headers: headers(),
      body: JSON.stringify({ id }),
    });
    fetchData();
  };

  const updateMessage = async (id: string) => {
    if (!editText.trim()) return;
    await fetch(`${API_BASE}/api/messages`, {
      method: "PUT",
      headers: headers(),
      body: JSON.stringify({ id, text: editText }),
    });
    setEditingId(null);
    setEditText("");
    fetchData();
  };

  const addGreeting = async (period: Period) => {
    const text = newGreetings[period];
    if (!text.trim()) return;
    await fetch(`${API_BASE}/api/greetings`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ period, text }),
    });
    setNewGreetings((prev) => ({ ...prev, [period]: "" }));
    fetchData();
  };

  const deleteGreeting = async (period: Period, id: string) => {
    await fetch(`${API_BASE}/api/greetings`, {
      method: "DELETE",
      headers: headers(),
      body: JSON.stringify({ period, id }),
    });
    fetchData();
  };

  const updateGreeting = async (period: Period, id: string) => {
    if (!editText.trim()) return;
    await fetch(`${API_BASE}/api/greetings`, {
      method: "PUT",
      headers: headers(),
      body: JSON.stringify({ period, id, text: editText }),
    });
    setEditingId(null);
    setEditText("");
    fetchData();
  };

  if (!authed) {
    return (
      <div style={styles.page}>
        <div style={styles.loginBox}>
          <div style={{ fontSize: "3rem", marginBottom: "1rem" }}>❤️</div>
          <h1 style={styles.title}>Terminal Heartbeat</h1>
          <p style={{ color: "#666", marginBottom: "1.5rem", fontSize: "0.9rem" }}>
            Admin Panel
          </p>
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              setAuthError(false);
            }}
            onKeyDown={(e) => e.key === "Enter" && tryLogin()}
            style={{
              ...styles.input,
              marginBottom: "1rem",
              borderColor: authError ? "#dc1e32" : "#333",
            }}
          />
          {authError && (
            <p style={{ color: "#dc1e32", fontSize: "0.85rem", marginBottom: "0.75rem" }}>
              Password incorrecto
            </p>
          )}
          <button onClick={tryLogin} style={styles.btn}>
            Entrar
          </button>
        </div>
      </div>
    );
  }

  const now = new Date();
  const hour = now.getHours();
  const currentPeriod: Period =
    hour >= 6 && hour < 12
      ? "morning"
      : hour >= 12 && hour < 20
        ? "afternoon"
        : "night";
  const previewGreeting =
    greetings[currentPeriod]?.[0]?.text ||
    PERIOD_LABELS[currentPeriod];
  const previewMessage =
    messages.length > 0
      ? messages[Math.floor(Math.random() * messages.length)].text
      : "Agrega tu primer mensaje...";

  return (
    <div style={styles.page}>
      <div style={styles.header}>
        <h1 style={styles.title}>❤️ Terminal Heartbeat — Admin</h1>
      </div>

      {/* Preview */}
      <div style={styles.section}>
        <div style={styles.sectionTitle}>Preview del popup</div>
        <div style={styles.preview}>
          <div style={styles.previewGreeting}>{previewGreeting}</div>
          <div style={styles.previewSep} />
          <div style={styles.previewMsg}>{previewMessage}</div>
          <div
            style={{
              textAlign: "right",
              color: "rgba(220, 30, 50, 0.3)",
              marginTop: "0.5rem",
            }}
          >
            ♥
          </div>
        </div>
      </div>

      {/* Messages */}
      <div style={styles.section}>
        <div style={styles.sectionTitle}>
          💌 Mensajes ({messages.length})
        </div>
        {messages.map((msg) => (
          <div key={msg.id} style={styles.item}>
            {editingId === msg.id ? (
              <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: "0.5rem" }}>
                <textarea
                  value={editText}
                  onChange={(e) => setEditText(e.target.value)}
                  style={{ ...styles.textarea, flex: 1 }}
                  autoFocus
                />
                <div style={{ display: "flex", gap: "0.5rem", justifyContent: "flex-end" }}>
                  <button
                    onClick={() => setEditingId(null)}
                    style={styles.btnSmall}
                  >
                    Cancelar
                  </button>
                  <button
                    onClick={() => updateMessage(msg.id)}
                    style={styles.btn}
                  >
                    Guardar
                  </button>
                </div>
              </div>
            ) : (
              <>
                <span style={styles.itemText}>{msg.text}</span>
                <div style={{ display: "flex", gap: "0.5rem", flexShrink: 0 }}>
                  <button
                    onClick={() => {
                      setEditingId(msg.id);
                      setEditText(msg.text);
                    }}
                    style={styles.btnSmall}
                  >
                    Editar
                  </button>
                  <button
                    onClick={() => deleteMessage(msg.id)}
                    style={styles.btnDanger}
                  >
                    Borrar
                  </button>
                </div>
              </>
            )}
          </div>
        ))}
        <div style={{ marginTop: "0.75rem" }}>
          <textarea
            placeholder="Nuevo mensaje... (Enter para nueva linea)"
            value={newMsg}
            onChange={(e) => setNewMsg(e.target.value)}
            style={{ ...styles.textarea, width: "100%", marginBottom: "0.5rem" }}
            rows={3}
          />
          <button onClick={addMessage} style={styles.btn}>
            Agregar
          </button>
        </div>
      </div>

      {/* Greetings */}
      {(["morning", "afternoon", "night"] as Period[]).map((period) => (
        <div key={period} style={styles.section}>
          <div style={styles.sectionTitle}>
            {PERIOD_ICONS[period]} {PERIOD_LABELS[period]} (
            {greetings[period]?.length || 0})
          </div>
          {greetings[period]?.map((grt) => (
            <div key={grt.id} style={styles.item}>
              {editingId === grt.id ? (
                <>
                  <input
                    value={editText}
                    onChange={(e) => setEditText(e.target.value)}
                    onKeyDown={(e) =>
                      e.key === "Enter" && updateGreeting(period, grt.id)
                    }
                    style={{ ...styles.input, flex: 1 }}
                    autoFocus
                  />
                  <button
                    onClick={() => updateGreeting(period, grt.id)}
                    style={styles.btnSmall}
                  >
                    Guardar
                  </button>
                  <button
                    onClick={() => setEditingId(null)}
                    style={styles.btnSmall}
                  >
                    Cancelar
                  </button>
                </>
              ) : (
                <>
                  <span style={styles.itemText}>{grt.text}</span>
                  <button
                    onClick={() => {
                      setEditingId(grt.id);
                      setEditText(grt.text);
                    }}
                    style={styles.btnSmall}
                  >
                    Editar
                  </button>
                  <button
                    onClick={() => deleteGreeting(period, grt.id)}
                    style={styles.btnDanger}
                  >
                    Borrar
                  </button>
                </>
              )}
            </div>
          ))}
          <div style={styles.addRow}>
            <input
              placeholder={`Nuevo saludo de ${PERIOD_LABELS[period].toLowerCase()}...`}
              value={newGreetings[period]}
              onChange={(e) =>
                setNewGreetings((prev) => ({
                  ...prev,
                  [period]: e.target.value,
                }))
              }
              onKeyDown={(e) => e.key === "Enter" && addGreeting(period)}
              style={{ ...styles.input, flex: 1 }}
            />
            <button onClick={() => addGreeting(period)} style={styles.btn}>
              Agregar
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
