#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Повний HTTP-аналіз сайту на ocStore/OpenCart.
Визначає: ядро, шаблон, модулі Octemplates, сторонні модулі,
JS/CSS-бібліотеки, SEO-фічі, аналітику, мови, функціонал, категорії.

Залежності:  pip install requests  [beautifulsoup4 — опційно]
Використання: python ocstore_inspector.py https://vxauto.com.ua [--no-admin] [--save-html out.html]
"""
import sys, re, argparse, os

import requests
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

try:
    from bs4 import BeautifulSoup
    HAS_BS = True
except ImportError:
    HAS_BS = False


# ------------------------------------------------------------------ #
#  Утиліти
# ------------------------------------------------------------------ #
def fetch(url, session, timeout=25):
    try:
        return session.get(url, timeout=timeout, verify=False, allow_redirects=True)
    except Exception as e:
        print(f"  ! {url} — {e}")
        return None


def h(title):
    print(f"\n{'='*65}\n{title}\n{'='*65}")


# ------------------------------------------------------------------ #
#  /admin/ — точне визначення ocStore 3.x / 2.x
# ------------------------------------------------------------------ #
def check_admin(s, base):
    info = {'reachable': False}
    r = fetch(base.rstrip('/') + '/admin/', s)
    if not r or r.status_code != 200:
        return info
    info['reachable'] = True
    html = r.text
    if 'ocstore3_install' in html:
        info['edition'] = 'ocStore 3.x  (utm_source=ocstore3_install)'
    elif 'ocstore2_install' in html:
        info['edition'] = 'ocStore 2.x  (utm_source=ocstore2_install)'
    elif 'ocstore' in html.lower():
        info['edition'] = 'ocStore (utm не знайдено)'
    elif 'opencart' in html.lower():
        info['edition'] = 'OpenCart (не ocStore)'
    else:
        info['edition'] = 'невідомо'
    m = re.search(r'ocStore[^0-9]{0,40}(\d{4})\s*[-–—]\s*(\d{4})', html, re.I)
    if m:
        info['copyright'] = f"{m.group(1)}–{m.group(2)}"
    if 'menu-fix.css' in html:
        info['signature'] = 'menu-fix.css (фірмовий файл ocStore)'
    if re.search(r'fontawesome-free-([\d.]+)-web', html):
        info['fa_admin'] = re.search(r'fontawesome-free-([\d.]+)-web', html).group(1)
    return info


# ------------------------------------------------------------------ #
#  Базова інформація про сторінку
# ------------------------------------------------------------------ #
def analyze_page(html):
    d = {}
    d['doctype'] = 'HTML5' if html.lstrip().lower().startswith('<!doctype html>') else '?'
    m = re.search(r'<html[^>]*\blang=["\']([^"\']+)', html, re.I)
    d['lang'] = m.group(1) if m else '?'
    m = re.search(r'<html[^>]*\bdir=["\']([^"\']+)', html, re.I)
    d['dir'] = m.group(1) if m else '?'
    m = re.search(r'<title>([^<]*)</title>', html, re.I)
    d['title'] = m.group(1).strip() if m else ''
    for n in ('description', 'generator', 'theme-color'):
        m = re.search(rf'<meta[^>]+name=["\']{n}["\'][^>]+content=["\']([^"\']*)', html, re.I)
        d[f'meta_{n}'] = m.group(1) if m else ''
    d['hreflang'] = re.findall(r'<link[^>]+hreflang=["\']([^"\']+)["\']', html, re.I)
    m = re.search(r'<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)', html, re.I)
    d['canonical'] = m.group(1) if m else ''
    d['http_size_kb'] = round(len(html.encode('utf-8')) / 1024, 1)
    return d


# ------------------------------------------------------------------ #
#  Шаблон
# ------------------------------------------------------------------ #
def detect_theme(html):
    found = []
    if 'oct_deals' in html:
        hint = 'catalog/view/theme/oct_deals/'
        m = re.search(r'oct_deals/[^"\']*\?v=([\d.]+)', html)
        if m:
            hint += f'  (v={m.group(1)})'
        found.append(('Octemplates Deals', hint))

    m = re.search(r'catalog/view/theme/([a-z0-9_]+)/', html)
    if m and m.group(1) != 'oct_deals':
        found.append((f'Шаблон: {m.group(1)}', 'catalog/view/theme/...'))

    signs = []
    # triple-quoted raw string — безпечно для класів ["'"]
    m_fonts = re.search(r"""data-oct-fonts=['"]([^'"]+)""", html)
    if m_fonts:
        signs.append(f"fonts={m_fonts.group(1)}")
    if 'octDetectTheme' in html:
        signs.append('dark/light theme')
    if 'data-popup-options' in html:
        signs.append('popup-options')
    if signs:
        found.append(('  → ознаки Deals', ', '.join(signs)))
    return found


# ------------------------------------------------------------------ #
#  Модулі Octemplates
# ------------------------------------------------------------------ #
def detect_oct_modules(html):
    mods = []
    checks = {
        'Slideshow Plus (слайдер)': [r'slideshow-plus-', r'slideshowPlus\('],
        'Live Search (живий пошук)': [r'oct_live_search', r'ds_livesearch'],
        'Stickers (стікери)': [r'oct_stickers\.css'],
        'Subscribe (email-підписка)': [r'oct_subscribe/makeSubscribe'],
        'Cookie Policy (cookie-банер)': [r'getOctPolicy', r'oct-policy'],
        'Login Popup (вхід у попапі)': [r'octPopupLogin'],
        'Cart Popup (кошик у попапі)': [r'octPopupCart'],
        'Show More (підвантаження)': [r'octShowMoreModule\('],
        'Info Bar (інфо-смуга)': [r'oct-infobar', r'oct_information_bar'],
        'Fonts Switcher (шрифти)': [r'oct-fonts\.js', r'oct-fonts-'],
        'OCF Category Filter (преміум)': [r'ocf-widget', r'findOcfFilters'],
        'Slick Carousel': [r'slick\.min\.js'],
        'Dark/Light Theme': [r'data-theme-toggle', r'octDetectTheme'],
    }
    for name, pats in checks.items():
        if any(re.search(p, html) for p in pats):
            mods.append(name)
    return mods


# ------------------------------------------------------------------ #
#  Сторонні модулі + аналітика
# ------------------------------------------------------------------ #
def detect_third_party(html):
    out = []
    m = re.search(r'microdatapro\s+(\d+\.\d+)', html, re.I)
    if m:
        out.append(f'Microdatapro {m.group(1)} (SEO: OG, JSON-LD, hCard)')
    elif 'microdatapro' in html.lower():
        out.append('Microdatapro (версія ?)')
    if 'sp_remarketing.js' in html:
        out.append('SP Remarketing (Google Ads / GA4 e-commerce)')
    if 'ecommerce_ga4_identifier' in html:
        out.append('GA4 e-commerce identifier')
    m = re.search(r'googletagmanager\.com/gtag/js\?id=(G-[A-Z0-9]+)', html)
    if m:
        out.append(f'Google Analytics 4: {m.group(1)}')
    m = re.search(r'googletagmanager\.com/gtm\.js\?id=(GTM-[A-Z0-9]+)', html)
    if m:
        out.append(f'Google Tag Manager: {m.group(1)}')
    if 'mc.yandex.ru/metrika' in html:
        out.append('Yandex.Metrika')
    if 'connect.facebook.net' in html and 'fbevents.js' in html:
        out.append('Meta Pixel')
    elif 'fbq(' in html:
        out.append('Meta Pixel (fbq)')
    if 'google.com/recaptcha' in html or 'gstatic.com/recaptcha' in html:
        out.append('Google reCAPTCHA')
    if re.search(r'href=["\'][^"\']*/blog', html):
        out.append('Блог (модуль)')
    return out


# ------------------------------------------------------------------ #
#  JS/CSS-бібліотеки з версіями
# ------------------------------------------------------------------ #
def detect_libs(html):
    libs = []
    m = re.search(r'jquery-([\d.]+)\.min\.js', html)
    if m:
        libs.append(f'jQuery {m.group(1)}')
    m = re.search(r'jqueryui/([\d.]+)/jquery-ui\.min\.js', html)
    if m:
        libs.append(f'jQuery UI {m.group(1)} (CDN)')
    # Bootstrap
    if 'bootstrap' in html:
        if re.search(r'\b(ms|me|ps|pe)-(sm|md|lg|xl)?-?\d', html):
            libs.append('Bootstrap 5')
        elif re.search(r'\b(ml|mr|pl|pr)-(sm|md|lg|xl)?-?\d', html):
            libs.append('Bootstrap 4')
        elif 'col-xs-' in html:
            libs.append('Bootstrap 3')
        else:
            libs.append('Bootstrap (версія не визначена)')
    if 'slick.min.js' in html:
        libs.append('Slick Carousel')
    m = re.search(r'fontawesome-free-([\d.]+)-web', html)
    if m:
        libs.append(f'FontAwesome {m.group(1)}')
    elif 'font-awesome' in html or 'fontawesome' in html:
        libs.append('FontAwesome (4.x/5.x)')
    if 'swiper' in html.lower():
        libs.append('Swiper')
    if 'vue.min.js' in html or 'vue.js' in html:
        libs.append('Vue.js')
    return libs


# ------------------------------------------------------------------ #
#  Функціонал фронту
# ------------------------------------------------------------------ #
def detect_features(html):
    f = []
    if '/wishlist/' in html or 'data-wishlist-ids' in html:
        f.append('Wishlist (закладки)')
    if '/compare-products/' in html or 'data-compare-ids' in html:
        f.append('Compare (порівняння)')
    if 'data-theme-toggle' in html:
        f.append('Перемикач темна/світла тема')
    if 'data-oct-fonts' in html:
        f.append('Перемикач шрифтів')
    if 'loading="lazy"' in html:
        f.append('Lazy-load зображень')
    if '/image/cache/webp/' in html:
        f.append('WebP-кеш (конвертація в WebP)')
    if '/brands' in html:
        f.append('Сторінка брендів')
    if '/blog' in html:
        f.append('Блог')
    if re.search(r'href=["\'][^"\']*/pidbir-', html):
        f.append('Кастомна сторінка підбору')
    if 'оптові' in html.lower() or 'opt-' in html:
        f.append('Оптові продажі (розділ)')
    langs = re.findall(r'<button[^>]+name=["\']([a-z]{2}-[a-z]{2})["\'][^>]*class=["\'][^"\']*language-select', html)
    if langs:
        f.append(f'Мови інтерфейсу: {", ".join(sorted(set(langs)))}')
    # Меню з іконками
    if 'ds-menu-catalog-item-img' in html:
        f.append('Мега-меню з іконками (WebP 84x84)')
    return f


# ------------------------------------------------------------------ #
#  SEO
# ------------------------------------------------------------------ #
def detect_seo(html):
    s = []
    if re.search(r'<meta[^>]+property=["\']og:', html):
        s.append('OpenGraph (og:*)')
    if 'application/ld+json' in html:
        types = sorted(set(re.findall(r'"@type"\s*:\s*"([^"]+)"', html)))
        s.append(f'JSON-LD: {", ".join(types) if types else "—"}')
    if 'hreflang' in html:
        s.append('hreflang (мультимовність)')
    if re.search(r'rel=["\']canonical["\']', html):
        s.append('canonical')
    if 'vcard' in html or 'hcard' in html.lower():
        s.append('hCard-мікророзмітка')
    if 'theme-color' in html:
        s.append('meta theme-color')
    return s


# ------------------------------------------------------------------ #
#  Категорії мега-меню
# ------------------------------------------------------------------ #
def extract_categories(html):
    cats = []
    if HAS_BS:
        soup = BeautifulSoup(html, 'html.parser')
        for a in soup.find_all('a', class_='ds-menu-maincategories-item-title'):
            cats.append((a.get_text(strip=True), a.get('href', '')))
        if cats:
            return cats
    # Fallback
    for m in re.finditer(
        r'<a\s+[^>]*href=["\']([^"\']+)["\'][^>]*class=["\'][^"\']*ds-menu-maincategories-item-title[^"\']*["\'][^>]*>([^<]+)</a>',
        html, re.I | re.S
    ):
        cats.append((m.group(2).strip(), m.group(1)))
    return cats


# ------------------------------------------------------------------ #
#  MAIN
# ------------------------------------------------------------------ #
def main():
    ap = argparse.ArgumentParser(description='Аналіз ocStore/OpenCart-сайту через HTTP')
    ap.add_argument('url', help='URL (напр. https://vxauto.com.ua)')
    ap.add_argument('--no-admin', action='store_true', help='Не перевіряти /admin/')
    ap.add_argument('--save-html', metavar='PATH', help='Зберегти HTML для дебагу')
    args = ap.parse_args()

    base = args.url.rstrip('/')
    if not base.startswith(('http://', 'https://')):
        base = 'https://' + base

    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                      '(KHTML, like Gecko) Chrome/120 Safari/537.36',
        'Accept-Language': 'uk-UA,uk;q=0.9,en;q=0.5',
    })

    print(f"\n🌐  {base}")
    print('=' * 65)

    # 1. Головна
    r = fetch(base, s)
    if not r or r.status_code != 200:
        print(f"✗ Головна недоступна (HTTP {getattr(r, 'status_code', '?')})")
        sys.exit(1)
    html = r.text
    if args.save_html:
        with open(args.save_html, 'w', encoding='utf-8') as f:
            f.write(html)
        print(f"  (HTML збережено: {args.save_html})")
    print(f"HTTP {r.status_code}   Server: {r.headers.get('Server', '?')}"
          f"   X-Powered-By: {r.headers.get('X-Powered-By', '—')}")
    print(f"Розмір HTML: {len(html.encode('utf-8')):,} байт")

    # 2. Базові дані
    page = analyze_page(html)
    h('📄 Сторінка')
    print(f"  Title:       {page['title'][:80]}")
    print(f"  Мова:        {page['lang']}   (dir={page['dir']})")
    if page['hreflang']:
        print(f"  hreflang:    {', '.join(page['hreflang'])}")
    if page['canonical']:
        print(f"  canonical:   {page['canonical']}")
    if page['meta_generator']:
        print(f"  generator:   {page['meta_generator']}")
    if page['meta_theme-color']:
        print(f"  theme-color: {page['meta_theme-color']}")

    # 3. Адмінка
    if not args.no_admin:
        h('🔐 Адмінка (/admin/)')
        adm = check_admin(s, base)
        if adm.get('reachable'):
            print(f"  Версія:    {adm.get('edition', '?')}")
            if adm.get('copyright'):
                print(f"  Copyright: ocStore © {adm['copyright']}")
            if adm.get('signature'):
                print(f"  Signature: {adm['signature']}")
            if adm.get('fa_admin'):
                print(f"  FA (admin): {adm['fa_admin']}")
        else:
            print("  ✗ /admin/ недоступна")

    # 4. Шаблон
    h('🎨 Шаблон')
    themes = detect_theme(html)
    if themes:
        for name, hint in themes:
            print(f"  ✓ {name:<24} [{hint}]")
    else:
        print("  ? Шаблон не визначено")

    # 5. Модулі Octemplates
    h('🧩 Модулі Octemplates')
    mods = detect_oct_modules(html)
    if mods:
        for m in mods:
            print(f"  ✓ {m}")
    else:
        print("  ✗ не виявлено")

    # 6. Сторонні модулі + аналітика
    h('🔧 Сторонні модулі та аналітика')
    third = detect_third_party(html)
    if third:
        for t in third:
            print(f"  ✓ {t}")
    else:
        print("  (не виявлено)")

    # 7. Бібліотеки
    h('📚 JS/CSS-бібліотеки')
    libs = detect_libs(html)
    if libs:
        for l in libs:
            print(f"  • {l}")
    else:
        print("  (не виявлено)")

    # 8. Функціонал
    h('⚙️  Функціональність фронту')
    for f_ in detect_features(html):
        print(f"  ✓ {f_}")

    # 9. SEO
    h('🌍 SEO-фічі')
    for s_ in detect_seo(html):
        print(f"  ✓ {s_}")

    # 10. Категорії
    cats = extract_categories(html)
    if cats:
        h(f'📂 Головні категорії мега-меню ({len(cats)})')
        for name, href in cats[:40]:
            print(f"  • {name:<40}  {href}")
        if len(cats) > 40:
            print(f"  … ще {len(cats) - 40}")

    print('\n' + '=' * 65)
    print('✅ Готово')


if __name__ == '__main__':
    main()