import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowUpRight, LockKeyhole } from 'lucide-react';
import { supabase } from './data';

export function PasswordRecovery() {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [checking, setChecking] = useState(true);
  const [hasRecoverySession, setHasRecoverySession] = useState(false);
  const [message, setMessage] = useState('');
  const [done, setDone] = useState(false);

  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(({ data }) => {
      if (active) {
        setHasRecoverySession(Boolean(data.session));
        setChecking(false);
      }
    });
    const { data } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'PASSWORD_RECOVERY' || session) setHasRecoverySession(Boolean(session));
    });
    return () => {
      active = false;
      data.subscription.unsubscribe();
    };
  }, []);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!hasRecoverySession) {
      setMessage('This reset link is invalid or has expired. Request a new link from the sign-in page.');
      return;
    }
    if (password.length < 12) {
      setMessage('Use at least 12 characters for your new password.');
      return;
    }
    if (password !== confirm) {
      setMessage('The passwords do not match.');
      return;
    }
    setBusy(true);
    setMessage('');
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setBusy(false);
      setMessage(error.message);
      return;
    }
    await supabase.auth.signOut();
    setBusy(false);
    setDone(true);
    setMessage('Your password has been updated. You can now sign in with the new password.');
  }

  return <main className="login">
    <Link className="brand" to="/en">AUREL<span>ESTATE</span></Link>
    <LockKeyhole size={28} aria-hidden="true" />
    <h1>Choose a new password.</h1>
    {checking ? <p>Checking your secure reset link…</p> :
      done ? <><p role="status">{message}</p><Link className="button" to="/admin">Continue to sign in <ArrowUpRight size={16}/></Link></> :
      !hasRecoverySession ? <><p role="alert">This reset link is invalid or has expired. Please request a new one.</p><Link className="button" to="/admin">Back to sign in <ArrowUpRight size={16}/></Link></> :
      <form onSubmit={submit}>
        <label>New password<input type="password" autoComplete="new-password" minLength={12} value={password} onChange={e => setPassword(e.target.value)} required /></label>
        <label>Confirm new password<input type="password" autoComplete="new-password" minLength={12} value={confirm} onChange={e => setConfirm(e.target.value)} required /></label>
        <button className="button" disabled={busy}>{busy ? 'Updating…' : 'Update password'}</button>
        {message && <p role="alert">{message}</p>}
      </form>}
  </main>;
}
