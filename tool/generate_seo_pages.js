const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DATA = JSON.parse(fs.readFileSync(path.join(__dirname, 'seo_content.json'), 'utf8'));
const OUT = path.join(ROOT, 'web', 'skills-exchange');
const SITE = 'https://palturo.app';
const TODAY = '2026-11-24';
const APP_CTA = '/?utm_source=skills_exchange&utm_medium=seo&utm_campaign=organic';

const esc = (value) =>
  String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const json = (value) =>
  JSON.stringify(value).replace(/</g, '\\u003c').replace(/>/g, '\\u003e');

const write = (rel, html) => {
  const file = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, html);
};

const crumb = (items) =>
  `<nav class="crumbs" aria-label="Breadcrumb">${items
    .map((item, i) =>
      i === items.length - 1
        ? `<span aria-current="page">${esc(item.label)}</span>`
        : `<a href="${item.href}">${esc(item.label)}</a><span class="sep">/</span>`,
    )
    .join('')}</nav>`;

const header = () => `
<header class="site-head">
  <a class="brand" href="/skills-exchange/" aria-label="PalTuro Skills Exchange">
    <img src="/skills-exchange/assets/wordmark-dark.png" alt="PalTuro" width="150" height="53">
    <span>Skills Exchange</span>
  </a>
  <nav class="head-nav" aria-label="Primary">
    <a href="/skills-exchange/">All skills</a>
    <a href="https://docs.palturo.app/">Field guide</a>
    <a class="button" href="${APP_CTA}">Open PalTuro</a>
  </nav>
</header>`;

const footer = (categories) => `
<footer class="site-foot">
  <div class="foot-grid">
    <div>
      <img src="/skills-exchange/assets/wordmark-light.png" alt="PalTuro" width="140" height="49">
      <p>A free community skills exchange for the Philippines. Teach what you know. Learn what you love.</p>
    </div>
    <div>
      <strong>Categories</strong>
      ${categories
        .map((c) => `<a href="/skills-exchange/${c.slug}/">${esc(c.name)}</a>`)
        .join('')}
    </div>
    <div>
      <strong>PalTuro</strong>
      <a href="${APP_CTA}">Open the app</a>
      <a href="https://docs.palturo.app/">Field guide</a>
      <a href="/">Home</a>
    </div>
  </div>
  <div class="foot-base">
    <span>© 2026 PalTuro</span>
    <span>Community skills exchange · Philippines</span>
  </div>
</footer>`;

const shell = ({ title, description, canonical, body, jsonLd }) => `<!doctype html>
<html lang="en-PH">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(title)}</title>
  <meta name="description" content="${esc(description)}">
  <link rel="canonical" href="${canonical}">
  <meta name="robots" content="index,follow">
  <meta name="theme-color" content="#262626">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="PalTuro">
  <meta property="og:title" content="${esc(title)}">
  <meta property="og:description" content="${esc(description)}">
  <meta property="og:url" content="${canonical}">
  <meta property="og:image" content="${SITE}/icons/Icon-512.png">
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="${esc(title)}">
  <meta name="twitter:description" content="${esc(description)}">
  <meta name="twitter:image" content="${SITE}/icons/Icon-512.png">
  <link rel="icon" href="/favicon-32.png" sizes="32x32">
  <link rel="stylesheet" href="/skills-exchange/seo.css">
  <script type="application/ld+json">${json(jsonLd)}</script>
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  ${header()}
  <main id="main">${body}</main>
  ${footer(DATA.categories)}
</body>
</html>`;

const faqHtml = (items) => `
<div class="faq">
  ${items
    .map(
      (item) => `
  <details>
    <summary>${esc(item.q)}</summary>
    <p>${esc(item.a)}</p>
  </details>`,
    )
    .join('')}
</div>`;

const chips = (items) =>
  items && items.length
    ? `<div class="chips">${items.map((item) => `<span>${esc(item)}</span>`).join('')}</div>`
    : '';

const commonHow = (label) => `
<section class="prose">
  <h2>How a skills exchange works</h2>
  <p>A skills exchange is a reciprocal arrangement: you learn something you want, and you offer something you can teach in return. It is not a paid course and it is not a one-way lecture. The exchange is built around two people who each have something useful to share.</p>
  <p>On PalTuro, you create a profile with the skills you can teach and the skills you want to learn. Matching looks at both directions, so the mentor you find is also getting a learner who can offer something back. Chat opens only after both people accept a request.</p>
</section>
<section class="prose">
  <h2>Why learn ${esc(label)} through a person, not a feed</h2>
  <p>Learning ${esc(label)} is easier to understand when someone can watch what you are doing, correct the small mistakes, and explain why a step matters. A mentor can adapt the pace to your materials, your space, and your experience.</p>
  <p>That feedback loop is the advantage of a community skills exchange. You are not collecting videos; you are building a relationship with someone who can answer the question you did not know how to ask.</p>
</section>`;

const commonSafety = () => `
<section class="prose">
  <h2>Safety and expectations</h2>
  <ul class="checklist">
    <li>Agree on the scope of the exchange before the first session.</li>
    <li>Meet in a public or shared space for an in-person first session.</li>
    <li>Ask about tools, materials, and physical requirements in advance.</li>
    <li>Keep personal details private until you trust the other person.</li>
    <li>Use the block and report tools if something feels wrong.</li>
  </ul>
</section>`;

const cta = (label) => `
<section class="cta">
  <div>
    <h2>${esc(label)}</h2>
    <p>Join a free community skills exchange. Teach a skill you know, learn one you want, and meet someone who wants to exchange both.</p>
  </div>
  <a class="button button-dark" href="${APP_CTA}">Open PalTuro</a>
</section>`;

const categoryCard = (category) => `
<a class="card" href="/skills-exchange/${category.slug}/">
  <span class="card-kicker">Skills exchange</span>
  <h3>${esc(category.name)}</h3>
  <p>${esc(category.blurb)}</p>
  <span class="card-link">Explore ${esc(category.name)} →</span>
</a>`;

const skillCard = (category, skill, group = null) => `
<a class="card" href="/skills-exchange/${category.slug}/${group ? `${group.slug}/` : ''}${skill.slug}/">
  <span class="card-kicker">${esc(category.name)}</span>
  <h3>${esc(skill.name)}</h3>
  <p>${esc(skill.summary)}</p>
  <span class="card-link">Explore ${esc(skill.name)} →</span>
</a>`;

const renderHub = () => {
  const allSkills = DATA.categories.flatMap((category) =>
    category.skills.flatMap((skill) =>
      skill.children
        ? [{ category, skill, child: null }, ...skill.children.map((child) => ({ category, skill, child }))]
        : [{ category, skill, child: null }],
    ),
  );
  const faqs = [
    {
      q: 'What is a skills exchange?',
      a: 'A skills exchange is a reciprocal way to learn. One person teaches a skill they know, and the other teaches something in return. PalTuro is a community skills exchange for the Philippines, not a paid course marketplace.',
    },
    {
      q: 'Is PalTuro free?',
      a: 'Yes. PalTuro is free to join. The exchange is based on sharing skills, not paying for lessons or subscriptions.',
    },
    {
      q: 'Do I have to teach a skill to join?',
      a: 'You can start by exploring, but the exchange works best when you can offer something back. It does not have to be a formal skill; a practical ability, a craft, or a language you speak can be useful.',
    },
    {
      q: 'Is this the same as “skill exchange” or “skills exchange”?',
      a: 'Yes. People search for both “skill exchange” and “skills exchange.” PalTuro uses the plural form for the category, but the idea is the same: a community where people trade knowledge instead of fees.',
    },
    {
      q: 'Can I learn online?',
      a: 'Many skills can start online, but some need in-person practice for safety, materials, or technique. Agree on the format with your mentor before the first session.',
    },
    {
      q: 'How do I start?',
      a: 'Create a profile with what you can teach and what you want to learn, then browse categories, review profiles, and send a request. Chat opens only after both people accept.',
    },
  ];
  const body = `
  <section class="hero">
    ${crumb([{ label: 'Home', href: '/' }, { label: 'Skills Exchange' }])}
    <p class="eyebrow">Community skills exchange · Philippines</p>
    <h1>Skills Exchange in the Philippines</h1>
    <p class="lede">PalTuro is a free community skills exchange where Filipinos teach what they know and learn what they love. Browse real skill categories, find a mentor, and offer something back.</p>
    <div class="hero-actions">
      <a class="button" href="${APP_CTA}">Open PalTuro</a>
      <a class="text-link" href="#categories">Browse categories ↓</a>
    </div>
  </section>

  <section class="prose">
    <h2>What “skills exchange” means</h2>
    <p>A skills exchange is simple: two people trade knowledge. You might learn Filipino cooking from a home cook and teach them basic photo editing or conversational English in return. The exchange is not a one-way class, and it is not a paid subscription.</p>
    <p>PalTuro adds structure to that idea. Profiles show what each person can teach and wants to learn. Reciprocal matching looks at both sides, so suggestions make sense for the mentor and the learner. Chat opens only after both people accept a request.</p>
  </section>

  <section id="categories">
    <h2>Browse skills exchange categories</h2>
    <div class="grid">${DATA.categories.map(categoryCard).join('')}</div>
  </section>

  <section class="prose">
    <h2>Skills you can exchange</h2>
    <p>These are the skills currently in the PalTuro taxonomy. Each one has its own page with what you can learn, what to prepare, and questions to ask a mentor.</p>
    <div class="skill-index">
      ${DATA.categories
        .map(
          (category) => `
      <div>
        <h3><a href="/skills-exchange/${category.slug}/">${esc(category.name)}</a></h3>
        <ul>
          ${category.skills
            .flatMap((skill) =>
              skill.children
                ? [
                    `<li><a href="/skills-exchange/${category.slug}/${skill.slug}/"><strong>${esc(skill.name)}</strong></a></li>`,
                    ...skill.children.map(
                      (child) =>
                        `<li class="child"><a href="/skills-exchange/${category.slug}/${skill.slug}/${child.slug}/">${esc(child.name)}</a></li>`,
                    ),
                  ]
                : [`<li><a href="/skills-exchange/${category.slug}/${skill.slug}/">${esc(skill.name)}</a></li>`],
            )
            .join('')}
        </ul>
      </div>`,
        )
        .join('')}
    </div>
  </section>

  ${commonHow('a skill')}

  <section class="prose">
    <h2>Why a community skills exchange</h2>
    <p>Paid courses are useful when you need a structured curriculum. A skills exchange is better when you need context, feedback, and a real person who can adapt to your situation. It is also a way to meet people in your community and keep a skill alive by teaching it.</p>
    <p>PalTuro is built around reciprocity, privacy, and safety. You decide who gets closer, and chat only opens after a request is accepted.</p>
  </section>

  ${commonSafety()}

  <section class="prose">
    <h2>Skills exchange questions</h2>
    ${faqHtml(faqs)}
  </section>

  ${cta('Find your next skills exchange')}`;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        name: 'Skills Exchange in the Philippines',
        description:
          'A free community skills exchange in the Philippines. Browse categories, learn a skill, and teach something in return.',
        url: `${SITE}/skills-exchange/`,
        inLanguage: 'en-PH',
        isPartOf: { '@type': 'WebSite', name: 'PalTuro', url: SITE },
      },
      {
        '@type': 'FAQPage',
        mainEntity: faqs.map((f) => ({
          '@type': 'Question',
          name: f.q,
          acceptedAnswer: { '@type': 'Answer', text: f.a },
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Home', item: SITE },
          {
            '@type': 'ListItem',
            position: 2,
            name: 'Skills Exchange',
            item: `${SITE}/skills-exchange/`,
          },
        ],
      },
    ],
  };

  write('index.html', shell({
    title: 'Skills Exchange in the Philippines | PalTuro',
    description:
      'PalTuro is a free community skills exchange in the Philippines. Browse skill categories, learn from a mentor, and teach something in return.',
    canonical: `${SITE}/skills-exchange/`,
    body,
    jsonLd,
  }));

  return allSkills;
};

const renderCategory = (category) => {
  const faqs = [
    {
      q: `What ${category.name} skills can I learn?`,
      a: `The ${category.name} category includes ${category.skills.map((s) => s.name).join(', ')}. Each skill page explains what you can learn, what to prepare, and how to find a mentor.`,
    },
    {
      q: `Is the ${category.name} skills exchange free?`,
      a: 'Yes. PalTuro is free to join. The exchange is reciprocal: you learn a skill and offer something you can teach in return.',
    },
    ...category.faqs,
  ];
  const body = `
  <section class="hero">
    ${crumb([
      { label: 'Home', href: '/' },
      { label: 'Skills Exchange', href: '/skills-exchange/' },
      { label: category.name },
    ])}
    <p class="eyebrow">Skills exchange · ${esc(category.name)}</p>
    <h1>${esc(category.name)} Skills Exchange</h1>
    <p class="lede">${esc(category.blurb)}</p>
    <div class="hero-actions">
      <a class="button" href="${APP_CTA}">Find a mentor in ${esc(category.name)}</a>
      <a class="text-link" href="/skills-exchange/">All categories</a>
    </div>
  </section>

  <section class="prose">
    ${category.intro.map((p) => `<p>${esc(p)}</p>`).join('')}
  </section>

  <section>
    <h2>${esc(category.name)} skills</h2>
    <div class="grid">${category.skills.map((skill) => skillCard(category, skill)).join('')}</div>
  </section>

  <section class="prose">
    <h2>Who this is for</h2>
    <p>This category is for anyone who wants to learn these skills from a person who practices them. You might be a beginner, a returning learner, or someone who wants to refresh a skill for work or family life.</p>
    <p>You do not need to be an expert to join. If you can offer a different skill in return, you have something to bring to the exchange.</p>
  </section>

  ${commonHow('these skills')}

  <section class="prose">
    <h2>${esc(category.name)} skills exchange questions</h2>
    ${faqHtml(faqs)}
  </section>

  <section class="prose">
    <h2>Explore other categories</h2>
    <div class="grid">${DATA.categories
      .filter((c) => c.slug !== category.slug)
      .slice(0, 3)
      .map(categoryCard)
      .join('')}</div>
  </section>

  ${cta(`Start a ${category.name} skills exchange`)}`;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        name: `${category.name} Skills Exchange`,
        description: category.blurb,
        url: `${SITE}/skills-exchange/${category.slug}/`,
        inLanguage: 'en-PH',
        isPartOf: { '@type': 'WebSite', name: 'PalTuro', url: SITE },
      },
      {
        '@type': 'FAQPage',
        mainEntity: faqs.map((f) => ({
          '@type': 'Question',
          name: f.q,
          acceptedAnswer: { '@type': 'Answer', text: f.a },
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Home', item: SITE },
          { '@type': 'ListItem', position: 2, name: 'Skills Exchange', item: `${SITE}/skills-exchange/` },
          { '@type': 'ListItem', position: 3, name: category.name, item: `${SITE}/skills-exchange/${category.slug}/` },
        ],
      },
    ],
  };

  write(`${category.slug}/index.html`, shell({
    title: `${category.name} Skills Exchange | PalTuro`,
    description: `Learn ${category.name} through PalTuro's free community skills exchange in the Philippines. ${category.blurb}`,
    canonical: `${SITE}/skills-exchange/${category.slug}/`,
    body,
    jsonLd,
  }));
};

const renderSkill = (category, skill, group) => {
  const isGroup = Boolean(skill.group);
  const children = skill.children || [];
  const siblings = isGroup
    ? []
    : group
      ? (group.children || []).filter((c) => c.slug !== skill.slug)
      : category.skills.filter((s) => s.slug !== skill.slug && !s.group);
  const related = siblings.slice(0, 3);
  const parent = group || category;
  const url = group
    ? `/skills-exchange/${category.slug}/${group.slug}/${skill.slug}/`
    : `/skills-exchange/${category.slug}/${skill.slug}/`;
  const crumbs = [
    { label: 'Home', href: '/' },
    { label: 'Skills Exchange', href: '/skills-exchange/' },
    { label: category.name, href: `/skills-exchange/${category.slug}/` },
    ...(group
      ? [{ label: group.name, href: `/skills-exchange/${category.slug}/${group.slug}/` }]
      : []),
    { label: skill.name },
  ];
  const faqs = [
    ...(skill.faqs || []),
    {
      q: `Is the ${skill.name} skills exchange free?`,
      a: 'Yes. PalTuro is free to join. You learn the skill and offer something you can teach in return; there is no subscription or per-lesson fee.',
    },
    {
      q: `Do I need experience to learn ${skill.name}?`,
      a: 'Most skill pages are written for beginners. Tell your mentor what you already know and what you want to be able to do, then agree on a starting point.',
    },
  ];
  const groupCards = isGroup
    ? `<section><h2>${esc(skill.name)} paths</h2><div class="grid">${children
        .map(
          (child) => `
      <a class="card" href="/skills-exchange/${category.slug}/${skill.slug}/${child.slug}/">
        <span class="card-kicker">${esc(category.name)}</span>
        <h3>${esc(child.name)}</h3>
        <p>${esc(child.summary)}</p>
        <span class="card-link">Explore ${esc(child.name)} →</span>
      </a>`,
        )
        .join('')}</div></section>`
    : '';
  const body = `
  <section class="hero">
    ${crumb(crumbs)}
    <p class="eyebrow">Skills exchange · ${esc(category.name)}</p>
    <h1>${esc(skill.name)} Skills Exchange</h1>
    <p class="lede">${esc(skill.summary)}</p>
    <div class="hero-actions">
      <a class="button" href="${APP_CTA}">Find a ${esc(skill.name)} mentor</a>
      <a class="text-link" href="/skills-exchange/${category.slug}/">Back to ${esc(category.name)}</a>
    </div>
  </section>

  ${isGroup ? groupCards : `
  <section class="prose">
    <h2>What you can learn in ${esc(skill.name)}</h2>
    <ul class="checklist">${skill.learn.map((item) => `<li>${esc(item)}</li>`).join('')}</ul>
  </section>

  <section class="prose">
    <h2>What to prepare</h2>
    <ul class="checklist">${skill.prepare.map((item) => `<li>${esc(item)}</li>`).join('')}</ul>
    ${skill.examples ? `<p class="examples-label">Common starting points</p>${chips(skill.examples)}` : ''}
  </section>

  <section class="prose">
    <h2>Questions to ask before your first ${esc(skill.name)} session</h2>
    <ul class="checklist">${skill.questions.map((item) => `<li>${esc(item)}</li>`).join('')}</ul>
  </section>`}

  ${commonHow(skill.name)}

  <section class="prose">
    <h2>Skills exchange vs paid classes</h2>
    <p>A paid class is useful when you need a fixed curriculum and a certificate. A skills exchange is better when you want context, feedback, and a relationship with someone who can adapt to your materials and pace. You are not buying a lesson; you are trading knowledge.</p>
  </section>

  ${commonSafety()}

  <section class="prose">
    <h2>${esc(skill.name)} skills exchange questions</h2>
    ${faqHtml(faqs)}
  </section>

  <section class="prose">
    <h2>Related skills</h2>
    <div class="grid">
      ${related.map((sibling) => skillCard(category, sibling, group)).join('')}
      <a class="card" href="/skills-exchange/${category.slug}/">
        <span class="card-kicker">Back to category</span>
        <h3>${esc(category.name)}</h3>
        <p>See every skill in this category.</p>
        <span class="card-link">Explore ${esc(category.name)} →</span>
      </a>
    </div>
  </section>

  ${cta(`Start a ${esc(skill.name)} skills exchange`)}`;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'LearningResource',
        name: `${skill.name} Skills Exchange`,
        description: skill.summary,
        url: `${SITE}${url}`,
        inLanguage: 'en-PH',
        learningResourceType: 'Skill exchange',
        teaches: skill.name,
        isPartOf: {
          '@type': 'CollectionPage',
          name: `${category.name} Skills Exchange`,
          url: `${SITE}/skills-exchange/${category.slug}/`,
        },
      },
      {
        '@type': 'FAQPage',
        mainEntity: faqs.map((f) => ({
          '@type': 'Question',
          name: f.q,
          acceptedAnswer: { '@type': 'Answer', text: f.a },
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: crumbs.map((item, i) => ({
          '@type': 'ListItem',
          position: i + 1,
          name: item.label,
          item: item.href ? `${SITE}${item.href}` : `${SITE}${url}`,
        })),
      },
    ],
  };

  write(`${category.slug}/${group ? `${group.slug}/` : ''}${skill.slug}/index.html`, shell({
    title: `${skill.name} Skills Exchange | PalTuro`,
    description: `Learn ${skill.name} through PalTuro's free skills exchange in the Philippines. ${skill.summary}`,
    canonical: `${SITE}${url}`,
    body,
    jsonLd,
  }));

  return url;
};

const main = () => {
  fs.mkdirSync(OUT, { recursive: true });
  for (const entry of fs.readdirSync(OUT)) {
    if (entry === 'assets' || entry === 'seo.css') continue;
    fs.rmSync(path.join(OUT, entry), { recursive: true, force: true });
  }
  renderHub();
  const urls = [
    { loc: '/', priority: '1.0' },
    { loc: '/skills-exchange/', priority: '1.0' },
  ];

  for (const category of DATA.categories) {
    renderCategory(category);
    urls.push({ loc: `/skills-exchange/${category.slug}/`, priority: '0.8' });
    for (const skill of category.skills) {
      const url = renderSkill(category, skill, null);
      urls.push({ loc: url, priority: '0.7' });
      if (skill.children) {
        for (const child of skill.children) {
          const childUrl = renderSkill(category, child, skill);
          urls.push({ loc: childUrl, priority: '0.7' });
        }
      }
    }
  }

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls
  .map(
    (u) => `  <url>
    <loc>${SITE}${u.loc}</loc>
    <lastmod>${TODAY}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>${u.priority}</priority>
  </url>`,
  )
  .join('\n')}
</urlset>
`;
  fs.writeFileSync(path.join(ROOT, 'web', 'sitemap.xml'), sitemap);

  const robots = `User-agent: *
Allow: /
Disallow: /confirm/
Disallow: /reset/
Disallow: /chat/
Disallow: /profile/
Disallow: /admin/
Sitemap: ${SITE}/sitemap.xml
`;
  fs.writeFileSync(path.join(ROOT, 'web', 'robots.txt'), robots);
  console.log(`generated ${urls.length} URLs`);
};

main();
