--
-- PostgreSQL database dump
--

\restrict i1Rx7QgB6heuVfmfShdQNpcF2Sc6MY0xhfPFZtKW5yItaT6d8h9iG8rxpWt10NA

-- Dumped from database version 16.9 (Debian 16.9-1.pgdg120+1)
-- Dumped by pg_dump version 18.0

-- Started on 2025-11-17 09:46:12 WITA

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- TOC entry 3486 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 215 (class 1259 OID 26190)
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid NOT NULL,
    username text,
    password text,
    email text NOT NULL,
    google_id text,
    profile_picture text,
    timezone text DEFAULT 'Asia/Jakarta'::text,
    google_access_token text,
    google_refresh_token text,
    token_expiry timestamp with time zone,
    last_synced_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 217 (class 1259 OID 26202)
-- Name: daily_tracks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.daily_tracks (
    id bigint NOT NULL,
    user_id uuid,
    name text NOT NULL,
    start timestamp with time zone NOT NULL,
    "end" timestamp with time zone NOT NULL,
    status text NOT NULL,
    read_only boolean DEFAULT false,
    sync_to_google boolean DEFAULT false,
    google_event_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 216 (class 1259 OID 26201)
-- Name: daily_tracks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.daily_tracks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3487 (class 0 OID 0)
-- Dependencies: 216
-- Name: daily_tracks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.daily_tracks_id_seq OWNED BY public.daily_tracks.id;


--
-- TOC entry 223 (class 1259 OID 26252)
-- Name: o_auth_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.o_auth_states (
    state text NOT NULL,
    user_id uuid,
    created_at timestamp with time zone,
    expires_at timestamp with time zone
);


--
-- TOC entry 222 (class 1259 OID 26244)
-- Name: origins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.origins (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 221 (class 1259 OID 26243)
-- Name: origins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.origins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3488 (class 0 OID 0)
-- Dependencies: 221
-- Name: origins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.origins_id_seq OWNED BY public.origins.id;


--
-- TOC entry 230 (class 1259 OID 26308)
-- Name: persona_consents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_consents (
    user_id uuid NOT NULL,
    a_ipersonalization boolean,
    allow_sensitive boolean,
    data_retention_days bigint,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 229 (class 1259 OID 26300)
-- Name: persona_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_profiles (
    user_id uuid NOT NULL,
    persona jsonb,
    version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 232 (class 1259 OID 26314)
-- Name: recurring_application_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_application_logs (
    id bigint NOT NULL,
    template_plan_id bigint NOT NULL,
    applied_date timestamp with time zone NOT NULL,
    generated_track_count bigint,
    success boolean,
    error_message text,
    synced_to_google boolean,
    created_at timestamp with time zone
);


--
-- TOC entry 231 (class 1259 OID 26313)
-- Name: recurring_application_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recurring_application_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3489 (class 0 OID 0)
-- Dependencies: 231
-- Name: recurring_application_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recurring_application_logs_id_seq OWNED BY public.recurring_application_logs.id;


--
-- TOC entry 228 (class 1259 OID 26285)
-- Name: share_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.share_tags (
    share_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- TOC entry 227 (class 1259 OID 26273)
-- Name: shares; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shares (
    id bigint NOT NULL,
    owner_user_id uuid NOT NULL,
    shared_to_user_id uuid NOT NULL,
    share_mode text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 226 (class 1259 OID 26272)
-- Name: shares_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shares_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3490 (class 0 OID 0)
-- Dependencies: 226
-- Name: shares_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shares_id_seq OWNED BY public.shares.id;


--
-- TOC entry 225 (class 1259 OID 26262)
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id bigint NOT NULL,
    owner_user_id uuid NOT NULL,
    name text NOT NULL,
    color text,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone
);


--
-- TOC entry 224 (class 1259 OID 26261)
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3491 (class 0 OID 0)
-- Dependencies: 224
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- TOC entry 220 (class 1259 OID 26222)
-- Name: template_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.template_plans (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    category text NOT NULL,
    plans text NOT NULL,
    owner_user_id uuid NOT NULL,
    public boolean DEFAULT false,
    is_recurring boolean DEFAULT false,
    repeat_mode character varying(20),
    days_of_week text,
    timezone character varying(50) DEFAULT 'UTC'::character varying,
    repeat_count bigint,
    conflict_mode character varying(20) DEFAULT 'error'::character varying,
    sync_to_google boolean DEFAULT false,
    next_run_date timestamp with time zone,
    last_applied_date timestamp with time zone,
    total_applied bigint DEFAULT 0,
    recurring_active boolean DEFAULT true,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- TOC entry 219 (class 1259 OID 26221)
-- Name: template_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.template_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3492 (class 0 OID 0)
-- Dependencies: 219
-- Name: template_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.template_plans_id_seq OWNED BY public.template_plans.id;


--
-- TOC entry 218 (class 1259 OID 26216)
-- Name: track_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.track_tags (
    track_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- TOC entry 3253 (class 2604 OID 26205)
-- Name: daily_tracks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_tracks ALTER COLUMN id SET DEFAULT nextval('public.daily_tracks_id_seq'::regclass);


--
-- TOC entry 3264 (class 2604 OID 26247)
-- Name: origins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origins ALTER COLUMN id SET DEFAULT nextval('public.origins_id_seq'::regclass);


--
-- TOC entry 3269 (class 2604 OID 26317)
-- Name: recurring_application_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_application_logs ALTER COLUMN id SET DEFAULT nextval('public.recurring_application_logs_id_seq'::regclass);


--
-- TOC entry 3266 (class 2604 OID 26276)
-- Name: shares id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares ALTER COLUMN id SET DEFAULT nextval('public.shares_id_seq'::regclass);


--
-- TOC entry 3265 (class 2604 OID 26265)
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- TOC entry 3256 (class 2604 OID 26225)
-- Name: template_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_plans ALTER COLUMN id SET DEFAULT nextval('public.template_plans_id_seq'::regclass);


--
-- TOC entry 3463 (class 0 OID 26190)
-- Dependencies: 215
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.accounts (id, username, password, email, google_id, profile_picture, timezone, google_access_token, google_refresh_token, token_expiry, last_synced_at, created_at, updated_at) FROM stdin;
48fbb529-6b5d-400d-9f02-a73f631a0634	rhyanz46	\N	rianariansaputra@gmail.com	105688661706680215580	https://lh3.googleusercontent.com/a/ACg8ocICvEdgHME-qcC42ACNr6mD04_dpn3zxzNzHSS6Z3zN0FhCrNFc=s96-c	Asia/Makassar	hzUecjRX5DNFB51phMGy7zTDNyskidt5c3v21fE9XsXMhKVeGDGcJxjESCRkDYtfAHQ9G9znXM21mRwCXAh6sg/7lphDdynf+F6RhvitT6+f84xcrbHHjRLB9yrZrn5aYF/VuXBKxZ0/34JWVe0DoDMCyZMmNptRb9FddEkJJCbDJ4nEeUC585/OBY5TmeAVNTWJ/1yy+kc1RRoWDONSOVlbJuyKs92D2NnhhcgBbiV7cA2rfKnY41PjwNJp+274kLfkMxk7X6ZfJ6Ru4KaKw1U9e8wKpRZoyLRsfLmodPhNi0oIWsILIJGQNGCQv+xR/5j3Qxfvv1mReEeRPVhObdgRA/3Annj93y6s8zjLIcargc+6MsnyPsU=	XsxPsyOwtHBtRxepJTia+/LnC0yCOCISyKvYmE70TPJ1z2kaaEj8qrcqXivdi3X4bGCzOwu+ueTXPfgtSG1IcczB6iTfJ/mC1bxYl4p9vVZ3nCLRTDni0XFQ/weRTPq+XttcpcyqidTbDRxmaxHR/sCAxHRlfru4poC+PK6QgJ1zixw=	2025-11-16 20:45:10.714268+00	\N	2025-11-16 19:39:16.247245+00	2025-11-16 20:33:00.537176+00
\.


--
-- TOC entry 3465 (class 0 OID 26202)
-- Dependencies: 217
-- Data for Name: daily_tracks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.daily_tracks (id, user_id, name, start, "end", status, read_only, sync_to_google, google_event_id, created_at, updated_at) FROM stdin;
6	48fbb529-6b5d-400d-9f02-a73f631a0634	Wake up & morning hygiene	2025-11-17 22:30:00+00	2025-11-17 23:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.554883+00	2025-11-16 20:49:49.554883+00
7	48fbb529-6b5d-400d-9f02-a73f631a0634	Light exercise (morning)	2025-11-17 23:00:00+00	2025-11-17 23:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.558709+00	2025-11-16 20:49:49.558709+00
8	48fbb529-6b5d-400d-9f02-a73f631a0634	Breakfast	2025-11-17 23:30:00+00	2025-11-18 00:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.560846+00	2025-11-16 20:49:49.560846+00
9	48fbb529-6b5d-400d-9f02-a73f631a0634	Prepare for work / commute	2025-11-18 00:00:00+00	2025-11-18 00:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.562511+00	2025-11-16 20:49:49.562511+00
10	48fbb529-6b5d-400d-9f02-a73f631a0634	Plan day	2025-11-18 00:30:00+00	2025-11-18 01:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.564566+00	2025-11-16 20:49:49.564566+00
11	48fbb529-6b5d-400d-9f02-a73f631a0634	Deep work session 1	2025-11-18 01:00:00+00	2025-11-18 02:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.566423+00	2025-11-16 20:49:49.566423+00
12	48fbb529-6b5d-400d-9f02-a73f631a0634	Break	2025-11-18 02:30:00+00	2025-11-18 03:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.568073+00	2025-11-16 20:49:49.568073+00
13	48fbb529-6b5d-400d-9f02-a73f631a0634	Deep work session 2	2025-11-18 03:00:00+00	2025-11-18 04:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.569717+00	2025-11-16 20:49:49.569717+00
14	48fbb529-6b5d-400d-9f02-a73f631a0634	Lunch break	2025-11-18 04:00:00+00	2025-11-18 05:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.57227+00	2025-11-16 20:49:49.57227+00
15	48fbb529-6b5d-400d-9f02-a73f631a0634	Light exercise (midday)	2025-11-18 05:00:00+00	2025-11-18 05:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.574512+00	2025-11-16 20:49:49.574512+00
16	48fbb529-6b5d-400d-9f02-a73f631a0634	Deep work session 3	2025-11-18 05:30:00+00	2025-11-18 07:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.585786+00	2025-11-16 20:49:49.585786+00
17	48fbb529-6b5d-400d-9f02-a73f631a0634	Afternoon break	2025-11-18 07:30:00+00	2025-11-18 08:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.588093+00	2025-11-16 20:49:49.588093+00
18	48fbb529-6b5d-400d-9f02-a73f631a0634	Deep work session 4	2025-11-18 08:00:00+00	2025-11-18 10:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.590998+00	2025-11-16 20:49:49.590998+00
19	48fbb529-6b5d-400d-9f02-a73f631a0634	Unwind / commute home	2025-11-18 10:00:00+00	2025-11-18 10:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.593175+00	2025-11-16 20:49:49.593175+00
20	48fbb529-6b5d-400d-9f02-a73f631a0634	Dinner	2025-11-18 10:30:00+00	2025-11-18 11:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.594506+00	2025-11-16 20:49:49.594506+00
21	48fbb529-6b5d-400d-9f02-a73f631a0634	Study session	2025-11-18 11:00:00+00	2025-11-18 12:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.595928+00	2025-11-16 20:49:49.595928+00
22	48fbb529-6b5d-400d-9f02-a73f631a0634	Evening wind down	2025-11-18 12:30:00+00	2025-11-18 13:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.598927+00	2025-11-16 20:49:49.598927+00
23	48fbb529-6b5d-400d-9f02-a73f631a0634	Leisure & prepare for sleep	2025-11-18 13:00:00+00	2025-11-18 14:00:00+00	not started	f	f	\N	2025-11-16 20:49:49.601548+00	2025-11-16 20:49:49.601548+00
24	48fbb529-6b5d-400d-9f02-a73f631a0634	Sleep	2025-11-18 14:00:00+00	2025-11-18 22:30:00+00	not started	f	f	\N	2025-11-16 20:49:49.604746+00	2025-11-16 20:49:49.604746+00
2	48fbb529-6b5d-400d-9f02-a73f631a0634	coba	2025-11-16 20:30:00+00	2025-11-16 21:25:00+00	not started	f	f	\N	2025-11-16 20:23:52.32007+00	2025-11-16 21:23:34.18957+00
25	48fbb529-6b5d-400d-9f02-a73f631a0634	sarapan	2025-11-16 22:35:00+00	2025-11-16 22:50:00+00	completed	f	f	\N	2025-11-16 22:41:31.920777+00	2025-11-16 22:48:38.125977+00
30	48fbb529-6b5d-400d-9f02-a73f631a0634	meeting	2025-11-17 03:00:00+00	2025-11-17 03:30:00+00	not started	f	f	\N	2025-11-16 22:53:57.974306+00	2025-11-16 22:53:57.974306+00
31	48fbb529-6b5d-400d-9f02-a73f631a0634	makan & tidur	2025-11-17 03:35:00+00	2025-11-17 05:55:00+00	not started	f	f	\N	2025-11-16 22:54:27.017221+00	2025-11-16 22:56:30.13413+00
32	48fbb529-6b5d-400d-9f02-a73f631a0634	prepare ke kape	2025-11-17 05:55:00+00	2025-11-17 06:20:00+00	not started	f	f	\N	2025-11-16 22:57:33.538531+00	2025-11-16 22:57:33.538531+00
33	48fbb529-6b5d-400d-9f02-a73f631a0634	random task	2025-11-17 06:30:00+00	2025-11-17 07:55:00+00	not started	f	f	\N	2025-11-16 22:58:06.103348+00	2025-11-16 22:58:06.103348+00
26	48fbb529-6b5d-400d-9f02-a73f631a0634	fix bug frontend	2025-11-16 22:55:00+00	2025-11-16 23:45:00+00	completed	f	f	\N	2025-11-16 22:43:44.658074+00	2025-11-16 23:34:50.338354+00
29	48fbb529-6b5d-400d-9f02-a73f631a0634	oprek varnish	2025-11-17 02:15:00+00	2025-11-17 02:55:00+00	not started	f	f	\N	2025-11-16 22:53:32.255908+00	2025-11-17 00:11:08.095297+00
28	48fbb529-6b5d-400d-9f02-a73f631a0634	baca dokumentasi varnish	2025-11-17 01:10:00+00	2025-11-17 01:55:00+00	not started	f	f	\N	2025-11-16 22:52:05.493069+00	2025-11-17 00:11:25.328846+00
27	48fbb529-6b5d-400d-9f02-a73f631a0634	backup service	2025-11-16 23:50:00+00	2025-11-17 01:00:00+00	not started	f	f	\N	2025-11-16 22:49:33.904847+00	2025-11-17 00:11:44.936318+00
\.


--
-- TOC entry 3471 (class 0 OID 26252)
-- Dependencies: 223
-- Data for Name: o_auth_states; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.o_auth_states (state, user_id, created_at, expires_at) FROM stdin;
\.


--
-- TOC entry 3470 (class 0 OID 26244)
-- Dependencies: 222
-- Data for Name: origins; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.origins (id, name, description, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 3478 (class 0 OID 26308)
-- Dependencies: 230
-- Data for Name: persona_consents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.persona_consents (user_id, a_ipersonalization, allow_sensitive, data_retention_days, created_at, updated_at) FROM stdin;
48fbb529-6b5d-400d-9f02-a73f631a0634	t	f	365	2025-11-16 19:46:39.229003+00	2025-11-16 19:46:39.229003+00
\.


--
-- TOC entry 3477 (class 0 OID 26300)
-- Dependencies: 229
-- Data for Name: persona_profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.persona_profiles (user_id, persona, version, created_at, updated_at) FROM stdin;
48fbb529-6b5d-400d-9f02-a73f631a0634	{"locale": "id-ID", "timezone": "Asia/Makassar", "constraints": {"hard_bounds": [{"dow": ["MON", "TUE", "WED", "THU", "FRI"], "end": "18:00", "start": "08:00"}]}, "motivations": {"primary_goal": "sehat", "secondary_goals": ["kaya", "pintar", "rutin"]}, "preferences": {"work_style": ["deep working"]}}	1	2025-11-16 19:46:39.218736+00	2025-11-16 19:46:39.218736+00
\.


--
-- TOC entry 3480 (class 0 OID 26314)
-- Dependencies: 232
-- Data for Name: recurring_application_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.recurring_application_logs (id, template_plan_id, applied_date, generated_track_count, success, error_message, synced_to_google, created_at) FROM stdin;
1	1	2025-11-16 16:00:00+00	0	f	existing tracks found on date 2025-11-17 and conflict mode is 'error'	f	2025-11-16 21:03:31.782521+00
2	1	2025-11-16 16:00:00+00	0	f	existing tracks found on date 2025-11-17 and conflict mode is 'error'	f	2025-11-16 22:08:25.1557+00
3	1	2025-11-16 16:00:00+00	0	f	existing tracks found on date 2025-11-17 and conflict mode is 'error'	f	2025-11-16 23:08:25.143654+00
4	1	2025-11-16 16:00:00+00	0	f	existing tracks found on date 2025-11-17 and conflict mode is 'error'	f	2025-11-17 00:08:25.143254+00
5	1	2025-11-16 16:00:00+00	0	f	existing tracks found on date 2025-11-17 and conflict mode is 'error'	f	2025-11-17 01:08:25.15781+00
\.


--
-- TOC entry 3476 (class 0 OID 26285)
-- Dependencies: 228
-- Data for Name: share_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.share_tags (share_id, tag_id) FROM stdin;
\.


--
-- TOC entry 3475 (class 0 OID 26273)
-- Dependencies: 227
-- Data for Name: shares; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.shares (id, owner_user_id, shared_to_user_id, share_mode, is_active, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 3473 (class 0 OID 26262)
-- Dependencies: 225
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tags (id, owner_user_id, name, color, deleted_at, created_at) FROM stdin;
1	48fbb529-6b5d-400d-9f02-a73f631a0634	votin	#FFEAA7	\N	2025-11-16 20:50:55.505301+00
2	48fbb529-6b5d-400d-9f02-a73f631a0634	fff	#4ECDC4	\N	2025-11-16 21:04:56.520177+00
3	48fbb529-6b5d-400d-9f02-a73f631a0634	kesehatan	#96CEB4	\N	2025-11-16 22:41:50.343361+00
4	48fbb529-6b5d-400d-9f02-a73f631a0634	cloudeka	#45B7D1	\N	2025-11-16 22:44:11.58673+00
\.


--
-- TOC entry 3468 (class 0 OID 26222)
-- Dependencies: 220
-- Data for Name: template_plans; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.template_plans (id, name, description, category, plans, owner_user_id, public, is_recurring, repeat_mode, days_of_week, timezone, repeat_count, conflict_mode, sync_to_google, next_run_date, last_applied_date, total_applied, recurring_active, created_at, updated_at) FROM stdin;
1	hari kerja	full kerja dari jam 9-12, 13-18 pengen makan olahraga tipis di pagi hari, terus siangnya pengen olah raga tipis juga, malamnya belajar	Work	[{"name":"Wake up & morning hygiene","start":"06:30","end":"07:00","status":"not started"},{"name":"Light exercise (morning)","start":"07:00","end":"07:30","status":"not started"},{"name":"Breakfast","start":"07:30","end":"08:00","status":"not started"},{"name":"Prepare for work / commute","start":"08:00","end":"08:30","status":"not started"},{"name":"Plan day","start":"08:30","end":"09:00","status":"not started"},{"name":"Deep work session 1","start":"09:00","end":"10:30","status":"not started"},{"name":"Break","start":"10:30","end":"11:00","status":"not started"},{"name":"Deep work session 2","start":"11:00","end":"12:00","status":"not started"},{"name":"Lunch break","start":"12:00","end":"13:00","status":"not started"},{"name":"Light exercise (midday)","start":"13:00","end":"13:30","status":"not started"},{"name":"Deep work session 3","start":"13:30","end":"15:30","status":"not started"},{"name":"Afternoon break","start":"15:30","end":"16:00","status":"not started"},{"name":"Deep work session 4","start":"16:00","end":"18:00","status":"not started"},{"name":"Unwind / commute home","start":"18:00","end":"18:30","status":"not started"},{"name":"Dinner","start":"18:30","end":"19:00","status":"not started"},{"name":"Study session","start":"19:00","end":"20:30","status":"not started"},{"name":"Evening wind down","start":"20:30","end":"21:00","status":"not started"},{"name":"Leisure & prepare for sleep","start":"21:00","end":"22:00","status":"not started"},{"name":"Sleep","start":"22:00","end":"06:30","status":"not started"}]	48fbb529-6b5d-400d-9f02-a73f631a0634	f	t	choose_days	[1,2,3,4,5]	UTC	\N	error	f	2025-11-16 00:00:00+00	\N	0	t	2025-11-16 20:47:06.569581+00	2025-11-16 20:47:06.569581+00
2	hari anak baik	aku seorang muslim, pengen jadi penuh ibadah di hari-hari penuh sibuk sebagai pekerja backend	Personal	[{"name":"Fajr prayer & dhikr","start":"05:30","end":"06:00","status":"not started"},{"name":"Quran reading","start":"06:00","end":"06:30","status":"not started"},{"name":"Light exercise","start":"06:30","end":"07:00","status":"not started"},{"name":"Breakfast & family time","start":"07:00","end":"07:45","status":"not started"},{"name":"Commute / prep for work","start":"07:45","end":"08:15","status":"not started"},{"name":"Deep work session","start":"08:15","end":"10:15","status":"not started"},{"name":"Short break (stretch & hydrate)","start":"10:15","end":"10:45","status":"not started"},{"name":"Deep work session","start":"10:45","end":"12:15","status":"not started"},{"name":"Dhuhr prayer & short rest","start":"12:15","end":"12:45","status":"not started"},{"name":"Lunch","start":"12:45","end":"13:30","status":"not started"},{"name":"Deep work session","start":"13:30","end":"15:30","status":"not started"},{"name":"Short break (walk & snack)","start":"15:30","end":"16:00","status":"not started"},{"name":"Deep work session","start":"16:00","end":"17:00","status":"not started"},{"name":"Asr prayer & reflection","start":"17:00","end":"17:30","status":"not started"},{"name":"Light tasks / email check","start":"17:30","end":"18:00","status":"not started"},{"name":"Commute home","start":"18:00","end":"18:30","status":"not started"},{"name":"Maghrib prayer & gratitude","start":"18:30","end":"19:00","status":"not started"},{"name":"Dinner","start":"19:00","end":"19:45","status":"not started"},{"name":"Family walk / relax","start":"19:45","end":"20:30","status":"not started"},{"name":"Isha prayer & Quran recitation","start":"20:30","end":"21:00","status":"not started"},{"name":"Personal development (reading / learning)","start":"21:00","end":"22:00","status":"not started"},{"name":"Light stretching & wind down","start":"22:00","end":"22:30","status":"not started"},{"name":"Prepare for bed & gratitude journal","start":"22:30","end":"23:00","status":"not started"}]	48fbb529-6b5d-400d-9f02-a73f631a0634	f	f			UTC	\N	error	f	\N	\N	0	t	2025-11-16 22:26:25.292615+00	2025-11-16 22:26:25.292615+00
\.


--
-- TOC entry 3466 (class 0 OID 26216)
-- Dependencies: 218
-- Data for Name: track_tags; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.track_tags (track_id, tag_id) FROM stdin;
\.


--
-- TOC entry 3493 (class 0 OID 0)
-- Dependencies: 216
-- Name: daily_tracks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.daily_tracks_id_seq', 33, true);


--
-- TOC entry 3494 (class 0 OID 0)
-- Dependencies: 221
-- Name: origins_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.origins_id_seq', 1, false);


--
-- TOC entry 3495 (class 0 OID 0)
-- Dependencies: 231
-- Name: recurring_application_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.recurring_application_logs_id_seq', 5, true);


--
-- TOC entry 3496 (class 0 OID 0)
-- Dependencies: 226
-- Name: shares_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.shares_id_seq', 1, false);


--
-- TOC entry 3497 (class 0 OID 0)
-- Dependencies: 224
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tags_id_seq', 4, true);


--
-- TOC entry 3498 (class 0 OID 0)
-- Dependencies: 219
-- Name: template_plans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.template_plans_id_seq', 2, true);


--
-- TOC entry 3271 (class 2606 OID 26197)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 3276 (class 2606 OID 26211)
-- Name: daily_tracks daily_tracks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.daily_tracks
    ADD CONSTRAINT daily_tracks_pkey PRIMARY KEY (id);


--
-- TOC entry 3296 (class 2606 OID 26258)
-- Name: o_auth_states o_auth_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.o_auth_states
    ADD CONSTRAINT o_auth_states_pkey PRIMARY KEY (state);


--
-- TOC entry 3292 (class 2606 OID 26251)
-- Name: origins origins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.origins
    ADD CONSTRAINT origins_pkey PRIMARY KEY (id);


--
-- TOC entry 3312 (class 2606 OID 26312)
-- Name: persona_consents persona_consents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_consents
    ADD CONSTRAINT persona_consents_pkey PRIMARY KEY (user_id);


--
-- TOC entry 3310 (class 2606 OID 26307)
-- Name: persona_profiles persona_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_profiles
    ADD CONSTRAINT persona_profiles_pkey PRIMARY KEY (user_id);


--
-- TOC entry 3316 (class 2606 OID 26321)
-- Name: recurring_application_logs recurring_application_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_application_logs
    ADD CONSTRAINT recurring_application_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 3308 (class 2606 OID 26289)
-- Name: share_tags share_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_tags
    ADD CONSTRAINT share_tags_pkey PRIMARY KEY (share_id, tag_id);


--
-- TOC entry 3306 (class 2606 OID 26281)
-- Name: shares shares_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shares
    ADD CONSTRAINT shares_pkey PRIMARY KEY (id);


--
-- TOC entry 3301 (class 2606 OID 26269)
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- TOC entry 3290 (class 2606 OID 26236)
-- Name: template_plans template_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.template_plans
    ADD CONSTRAINT template_plans_pkey PRIMARY KEY (id);


--
-- TOC entry 3282 (class 2606 OID 26220)
-- Name: track_tags track_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.track_tags
    ADD CONSTRAINT track_tags_pkey PRIMARY KEY (track_id, tag_id);


--
-- TOC entry 3272 (class 1259 OID 26199)
-- Name: idx_accounts_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_accounts_email ON public.accounts USING btree (email);


--
-- TOC entry 3273 (class 1259 OID 26198)
-- Name: idx_accounts_google_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_accounts_google_id ON public.accounts USING btree (google_id);


--
-- TOC entry 3274 (class 1259 OID 26200)
-- Name: idx_accounts_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_accounts_username ON public.accounts USING btree (username);


--
-- TOC entry 3277 (class 1259 OID 26213)
-- Name: idx_daily_tracks_end; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_daily_tracks_end ON public.daily_tracks USING btree ("end");


--
-- TOC entry 3278 (class 1259 OID 26212)
-- Name: idx_daily_tracks_google_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_daily_tracks_google_event_id ON public.daily_tracks USING btree (google_event_id);


--
-- TOC entry 3279 (class 1259 OID 26214)
-- Name: idx_daily_tracks_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_daily_tracks_start ON public.daily_tracks USING btree (start);


--
-- TOC entry 3280 (class 1259 OID 26215)
-- Name: idx_daily_tracks_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_daily_tracks_user_id ON public.daily_tracks USING btree (user_id);


--
-- TOC entry 3293 (class 1259 OID 26260)
-- Name: idx_o_auth_states_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_o_auth_states_created_at ON public.o_auth_states USING btree (created_at);


--
-- TOC entry 3294 (class 1259 OID 26259)
-- Name: idx_o_auth_states_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_o_auth_states_expires_at ON public.o_auth_states USING btree (expires_at);


--
-- TOC entry 3313 (class 1259 OID 26327)
-- Name: idx_recurring_application_logs_applied_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_application_logs_applied_date ON public.recurring_application_logs USING btree (applied_date);


--
-- TOC entry 3314 (class 1259 OID 26328)
-- Name: idx_recurring_application_logs_template_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_application_logs_template_plan_id ON public.recurring_application_logs USING btree (template_plan_id);


--
-- TOC entry 3302 (class 1259 OID 26282)
-- Name: idx_shares_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shares_is_active ON public.shares USING btree (is_active);


--
-- TOC entry 3303 (class 1259 OID 26284)
-- Name: idx_shares_owner_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shares_owner_user_id ON public.shares USING btree (owner_user_id);


--
-- TOC entry 3304 (class 1259 OID 26283)
-- Name: idx_shares_shared_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shares_shared_to_user_id ON public.shares USING btree (shared_to_user_id);


--
-- TOC entry 3297 (class 1259 OID 26270)
-- Name: idx_tags_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tags_deleted_at ON public.tags USING btree (deleted_at);


--
-- TOC entry 3298 (class 1259 OID 26329)
-- Name: idx_tags_owner_name_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tags_owner_name_deleted ON public.tags USING btree (owner_user_id, name, deleted_at);


--
-- TOC entry 3299 (class 1259 OID 26271)
-- Name: idx_tags_owner_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tags_owner_user_id ON public.tags USING btree (owner_user_id);


--
-- TOC entry 3283 (class 1259 OID 26242)
-- Name: idx_template_plans_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_plans_category ON public.template_plans USING btree (category);


--
-- TOC entry 3284 (class 1259 OID 26239)
-- Name: idx_template_plans_is_recurring; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_plans_is_recurring ON public.template_plans USING btree (is_recurring);


--
-- TOC entry 3285 (class 1259 OID 26238)
-- Name: idx_template_plans_next_run_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_plans_next_run_date ON public.template_plans USING btree (next_run_date);


--
-- TOC entry 3286 (class 1259 OID 26241)
-- Name: idx_template_plans_owner_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_plans_owner_user_id ON public.template_plans USING btree (owner_user_id);


--
-- TOC entry 3287 (class 1259 OID 26240)
-- Name: idx_template_plans_public; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_plans_public ON public.template_plans USING btree (public);


--
-- TOC entry 3288 (class 1259 OID 26237)
-- Name: idx_template_plans_recurring_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_template_plans_recurring_active ON public.template_plans USING btree (recurring_active);


--
-- TOC entry 3319 (class 2606 OID 26322)
-- Name: recurring_application_logs fk_recurring_application_logs_template_plan; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_application_logs
    ADD CONSTRAINT fk_recurring_application_logs_template_plan FOREIGN KEY (template_plan_id) REFERENCES public.template_plans(id);


--
-- TOC entry 3317 (class 2606 OID 26290)
-- Name: share_tags fk_share_tags_share; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_tags
    ADD CONSTRAINT fk_share_tags_share FOREIGN KEY (share_id) REFERENCES public.shares(id);


--
-- TOC entry 3318 (class 2606 OID 26295)
-- Name: share_tags fk_share_tags_tag; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.share_tags
    ADD CONSTRAINT fk_share_tags_tag FOREIGN KEY (tag_id) REFERENCES public.tags(id);


-- Completed on 2025-11-17 09:46:16 WITA

--
-- PostgreSQL database dump complete
--

\unrestrict i1Rx7QgB6heuVfmfShdQNpcF2Sc6MY0xhfPFZtKW5yItaT6d8h9iG8rxpWt10NA

