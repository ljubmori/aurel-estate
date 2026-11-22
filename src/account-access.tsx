import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowUpRight, LockKeyhole } from 'lucide-react';
import { supabase } from './data';

export function PasswordRecovery() {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [done, setDone] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
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
    setBusy(false);
    if (error) {
      setMessage(error.message);
      return;
    }
    setDone(true);
    setMessage('Your password has been updated. You can now sign in with the new password.');
  }

  return <main className="login">
    <Link className="brand" to="/en">AUREL<span>ESTATE</span></Link>
    <LockKeyhole size={28} aria-hidden="true" />
    <h1>Choose a new password.</h1>
    {done ? <><p role="status">{message}</p><Link className="button" to="/admin">Continue to sign in <ArrowUpRight size={16}/></Link></> :
      <form onSubmit={submit}>
        <label>New password<input type="password" autoComplete="new-password" minLength={12} value={password} onChange={e => setPassword(e.target.value)} required /></label>
        <label>Confirm new password<input type="password" autoComplete="new-password" minLength={12} value={confirm} onChange={e => setConfirm(e.target.value)} required /></label>
        <button className="button" disabled={busy}>{busy ? 'Updating…' : 'Update password'}</button>
        {message && <p role="alert">{message}</p>}
      </form>}
  </main>;
}
