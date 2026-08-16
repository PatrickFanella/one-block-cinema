"use client";

import { createBrowserClient } from "@supabase/ssr";
import { useState, type FormEvent } from "react";

export default function LoginPage() {
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const email = String(form.get("email") ?? "");
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anonKey) {
      setMessage("Console configuration is missing.");
      return;
    }
    const supabase = createBrowserClient(url, anonKey);
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
    });
    setMessage(error ? error.message : "Check your email for the secure sign-in link.");
  }

  return (
    <main className="login">
      <form onSubmit={submit}>
        <p className="eyebrow">ONE-BLOCK CINEMA</p>
        <h1>Moderator sign in</h1>
        <label>Email<input name="email" type="email" required autoComplete="email" /></label>
        <button className="approve">Send secure link</button>
        <p aria-live="polite">{message}</p>
      </form>
    </main>
  );
}
