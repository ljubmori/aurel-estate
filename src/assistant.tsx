import {useEffect, useRef, useState} from 'react';
import {Link, useLocation} from 'react-router-dom';
import {MessageCircle, Send, X} from 'lucide-react';
import {money} from './domain.mjs';
import type {Property} from './data';
import './assistant.css';

type Props = {
  lang: 'sr' | 'en';
  properties: Property[];
  loading: boolean;
  error: string;
  settings: {email: string; phone: string; address: string};
};
type Reply = {body: string; links?: {path: string; label: string}[]};
const normalize = (s: string) => s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();

export function Assistant(props: Props) {
  const {lang, properties, loading, error, settings} = props;
  const sr = lang === 'sr';
  const {pathname} = useLocation();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState('');
  const [turns, setTurns] = useState<{question: string; reply: Reply}[]>([]);
  const input = useRef<HTMLInputElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const log = useRef<HTMLDivElement>(null);
  useEffect(() => {if (open) input.current?.focus()}, [open]);
  useEffect(() => {if (log.current) log.current.scrollTop = log.current.scrollHeight}, [turns, open]);
  const heading = sr ? 'Pitajte agenta' : 'Ask the agent';
  const listingTitle = (p: Property) => sr && p.title_sr ? p.title_sr : p.title;
  const listingLink = (p: Property) => ({path: '/' + lang + '/properties/' + p.slug, label: listingTitle(p)});
  const contact = {path: '/' + lang + '/contact', label: sr ? 'Pišite agenciji' : 'Contact the agency'};
  const catalog = {path: '/' + lang + '/properties', label: sr ? 'Pogledajte ponudu' : 'Browse listings'};
  const published = properties.filter(p => p.status === 'published');
  const current = published.find(p => pathname === listingLink(p).path);
  const prompts = current
    ? [sr ? 'Kolika je cena?' : 'What is the price?', sr ? 'Kako da zakažem razgledanje?' : 'How do I book a viewing?']
    : [sr ? 'Šta imate za izdavanje?' : 'What is available to rent?', sr ? 'Kako da vas kontaktiram?' : 'How can I contact you?'];

  function answer(question: string): Reply {
    const q = normalize(question);
    if (/kontakt|contact|telefon|phone|email|mejl|adresa agencije/.test(q)) {
      return {body: [settings.email, settings.phone, settings.address].filter(Boolean).join('\n'), links: [contact]};
    }
    const named = published.find(p => [p.title, p.title_sr].some(t => t && q.includes(normalize(t))));
    const detail = named || current;
    if (/razgled|obilaz|obilask|termin|viewing|appointment/.test(q)) {
      return {body: sr ? 'U oglasu izaberite razgledanje i pošaljite željeni datum i vreme. Agencija će vas kontaktirati radi potvrde.' : 'Choose the viewing option on the listing and send your preferred date and time. The agency will contact you to confirm.', links: [detail ? listingLink(detail) : catalog]};
    }
    if (detail && /cen[aeu]|kosta|price|cost|how much|kvadrat|povrsin|area|size|bedroom|spavac|kupatil|bath|detalj|details/.test(q)) {
      return {body: [listingTitle(detail), money(detail,lang) + (detail.transaction === 'rent' ? (sr ? ' mesečno' : ' per month') : ''), detail.area + ' m²', (sr ? 'Spavaće sobe: ' : 'Bedrooms: ') + detail.bedrooms, (sr ? 'Kupatila: ' : 'Bathrooms: ') + detail.bathrooms].join('\n'), links: [listingLink(detail)]};
    }
    const rent = /izda[vj]|iznajm|zakup|rent/.test(q);
    const sale = /prodaj|kupov|kupim|buy|sale/.test(q);
    const cityQuery = q.replace(/beograd[a-z]*/g,'belgrade').replace(/londonu/g,'london');
    const city = published.find(p => p.city && cityQuery.includes(normalize(p.city)))?.city;
    if (named || rent || sale || city || /ponud|oglasi|listings|available properties/.test(q)) {
      if (loading || error) return {body: loading ? (sr ? 'Ponuda se učitava. Pitajte ponovo za trenutak.' : 'Listings are loading. Please ask again in a moment.') : (sr ? 'Ponuda je trenutno nedostupna.' : 'Listings are currently unavailable.'), links: [contact]};
      const matches = published.filter(p => (!named || p.id === named.id) && (!city || p.city === city) && (rent === sale || p.transaction === (rent ? 'rent' : 'sale')));
      const scope = [city, rent !== sale && (rent ? (sr ? 'izdavanje' : 'rent') : (sr ? 'prodaja' : 'sale'))].filter(Boolean).join(' · ');
      return {body: (sr ? 'Objavljeni oglasi' : 'Published listings') + (scope ? ' (' + scope + ')' : '') + ': ' + matches.length, links: [...matches.slice(0,4).map(listingLink), catalog]};
    }
    return {body: sr ? 'Za ovo pitanje obratite se agenciji. Mogu da prikažem oglase za prodaju ili izdavanje i objasnim kako da zakažete razgledanje.' : 'The agency can help with that question. I can show sale or rental listings and explain how to request a viewing.', links: [contact]};
  }
  function ask(question: string) {
    if (!question.trim()) return;
    setTurns(previous => [...previous, {question: question.trim(), reply: answer(question)}]);
    setDraft('');
    input.current?.focus();
  }
  function close() {setOpen(false); trigger.current?.focus()}
  return <div className="estate-chat" onKeyDown={e => {if (e.key === 'Escape') close()}}>
    {open && <section className="chat-panel" role="dialog" aria-label={heading} id="estate-chat-panel">
      <header><strong>{heading}</strong><button aria-label={sr ? 'Zatvori' : 'Close'} onClick={close}><X size={20}/></button></header>
      <div ref={log} className="chat-log" role="log" aria-live="polite">
        <p>{sr ? 'Dobar dan! Šta vas zanima o našoj ponudi ili razgledanju?' : 'Hello! What would you like to know about our listings or viewings?'}</p>
        {!turns.length && prompts.map(q => <button className="chat-prompt" key={q} onClick={() => ask(q)}>{q}</button>)}
        {turns.map(({question, reply}, i) => <div key={i}><p className="chat-question">{question}</p><p>{reply.body}</p>{reply.links?.map(link => <Link key={link.path} to={link.path} onClick={close}>{link.label}</Link>)}</div>)}
      </div>
      <form onSubmit={e => {e.preventDefault(); ask(draft)}}><input ref={input} aria-label={sr ? 'Vaše pitanje' : 'Your question'} placeholder={sr ? 'Napišite pitanje…' : 'Type your question…'} value={draft} maxLength={600} onChange={e => setDraft(e.target.value)}/><button disabled={!draft.trim()} aria-label={sr ? 'Pošalji' : 'Send'}><Send size={18}/></button></form>
    </section>}
    <button className="chat-trigger" ref={trigger} aria-expanded={open} aria-controls={open ? 'estate-chat-panel' : undefined} onClick={() => open ? close() : setOpen(true)}><MessageCircle size={20}/>{heading}</button>
  </div>;
}
