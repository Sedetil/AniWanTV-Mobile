# Scrape AniWanTV Mobile JS

Proyek ini menyediakan API Node.js untuk mengambil data anime dan komik dari situs sumber menggunakan proxy internal, parsing HTML dengan Cheerio, dan respons JSON yang stabil untuk aplikasi klien.

## Fitur
- Endpoint anime: top, latest, details, episode streams, search
- Endpoint komik: latest, popular, latest collections, details, chapter images, search
- Proxy internal dengan whitelist domain dan header yang mirip browser
- CORS aktif agar bisa diakses dari aplikasi front-end
- Fallback port otomatis dan `PROXY_BASE` dinamis mengikuti port server

## Prasyarat
- Node.js 18+ (disarankan 20/22)
- NPM

## Instalasi
- `npm install`

## Menjalankan Server
- `npm start`
- Endpoint kesehatan: `GET /` mengembalikan `I am alive!`
- Log saat start: `Listening on <port>`

## Konfigurasi (Environment Variables)
- `PORT`: port server (default 5000, ada fallback jika 5000 sudah dipakai)
- `PROXY_BASE`: base URL proxy (default dinamis `http://159.223.42.28:5000`)
- `PROXY_COOKIES`: cookie upstream tambahan untuk melewati proteksi (gabung dengan cookie klien)
- `RES_PROXY`: URL agen SOCKS (mis. `socks5h://127.0.0.1:1080`)
- `RES_PROXY_HOST`, `RES_PROXY_PORT`, `RES_PROXY_TYPE`: alternatif komposisi `RES_PROXY` (default `socks5h`)

Contoh set env (PowerShell):
- `$env:PORT=5001; npm start`
- `$env:PROXY_COOKIES='cf_clearance=...; __cf_bm=...'; npm start`
- `$env:RES_PROXY_TYPE='socks5h'; $env:RES_PROXY_HOST='127.0.0.1'; $env:RES_PROXY_PORT='1080'; npm start`

## Endpoints

### Anime
- `GET /top-anime`
  - Response: `{ success, data: [{ title, url, image_url }] }`
- `GET /latest-anime?page=<number>`
  - Response: `{ success, data: { anime_list: [...], current_page, total_pages } }`
- `GET /anime-details?url=<detail_url>`
  - Response: `{ success, data: { title, image_url, japanese, rating, producer, type, status, total_episodes, duration, release_date, studio, genres, synopsis, episodes } }`
- `GET /episode-streams?url=<episode_url>`
  - Response: `{ success, data: { title, stream_url, mirror_urls, download_links, direct_stream_urls } }`
  - `direct_stream_urls`: diisi dari link Pixeldrain (dinormalisasi ke `https://pixeldrain.com/api/file/<id>`) bila tersedia
- `GET /search?query=<text>`
  - Response: `{ success, data: [{ title, url, image_url }] }`

### Komik
- `GET /latest-comics?page=<number>`
  - Response: `{ success, data: { comic_list: [...], current_page, total_pages } }`
- `GET /popular-comics`
  - Response: `{ success, data: [{ title, url, image_url, author, rating, rank }] }`
- `GET /latest-collections`
  - Response: `{ success, data: [{ title, url, image_url, genres, rating }] }`
- `GET /comic-details?url=<detail_url>`
  - Response: `{ success, data: { title, image_url, rating, alternative_titles, status, author, illustrator, demographic, type, genres, themes, synopsis, chapters, related_comics, last_updated } }`
- `GET /chapter-images?url=<chapter_url>`
  - Response: `{ success, data: { title, description, images: [{ url, alt }], navigation, related_chapters } }`
- `GET /search-comics?query=<text>`
  - Response: `{ success, data: [{ title, url, image_url, type, rating }] }`

### Proxy
- `GET /proxy?url=<target_url>`
  - Hanya domain yang diizinkan (mis. otakudesu, komikindo)
  - Mengembalikan konten upstream dengan header CORS

## Contoh Penggunaan

Curl (Command Prompt/PowerShell):
- `curl "http://127.0.0.1:5000/top-anime"`
- `curl "http://127.0.0.1:5000/latest-anime?page=1"`
- `curl "http://127.0.0.1:5000/anime-details?url=https://otakudesu.best/anime/xxx/"`
- `curl "http://127.0.0.1:5000/episode-streams?url=https://otakudesu.best/episode/xxx/"`
- `curl "http://127.0.0.1:5000/latest-comics?page=1"`
- `curl "http://127.0.0.1:5000/latest-collections"`
- `curl "http://127.0.0.1:5000/chapter-images?url=https://komikindo.ch/xxx/"`

JavaScript (fetch):
- `fetch('/top-anime').then(r=>r.json())`
- `fetch('/episode-streams?url='+encodeURIComponent(epUrl)).then(r=>r.json())`

## Tips Hasil Lengkap
- Gunakan `PROXY_COOKIES` untuk meniru sesi yang berhasil (contoh: `cf_clearance`) bila upstream memakai proteksi.
- Bila perlu jaringan khusus, set `RES_PROXY`/`RES_PROXY_HOST` agar request upstream lebih stabil.
- Pastikan `url` parameter adalah URL lengkap dari halaman detail/episode/chapter.

## Error Handling
- `400` jika parameter wajib tidak ada (`url`/`query`)
- `403` jika host tidak diizinkan oleh proxy
- `502` jika upstream error atau timeout
- `500` jika parsing internal gagal

## Catatan Implementasi
- Server: `server.js` (Express, CORS, router). Fallback port otomatis dan log port aktif.
- Anime parser: `anime/scraper.js` (Cheerio, proxy fetch, ekstraksi robust termasuk Pixeldrain)
- Komik parser: `comics/scraper.js` (Cheerio, selector diperkuat untuk variasi layout)
- Proxy: `proxy/index.js` (Axios, whitelist, header browser-like, dukungan cookie & SOCKS)

## Lisensi
- Untuk keperluan edukasi dan eksperimen scraping. Gunakan dengan bijak sesuai ketentuan situs sumber.