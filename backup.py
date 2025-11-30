# ganti nama file nya dengan app.py kalau ingin berjalan normal untuk file backup ini

import flask
from flask import Flask, request, jsonify, render_template
from bs4 import BeautifulSoup
import requests
import re
import json
from flask_cors import CORS
import logging
import time
import urllib.parse
from threading import Thread
import uuid
from datetime import datetime, timedelta
import os

# Setup basic logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# App version data storage
APP_VERSION_FILE = 'app_version.json'

def load_app_version():
    """Load app version data from file"""
    default_version = {
        "version": "1.0.0",
        "download_url": "https://github.com/Sedetil/AniWanTV-Mobile/releases/download/v1.0.0/app-arm64-v8a-release.apk",
        "changelog": "Initial release"
    }
    
    try:
        if os.path.exists(APP_VERSION_FILE):
            with open(APP_VERSION_FILE, 'r') as f:
                return json.load(f)
        else:
            # Create default file if it doesn't exist
            save_app_version(default_version)
            return default_version
    except Exception as e:
        logger.error(f"Error loading app version: {e}")
        return default_version

def save_app_version(version_data):
    """Save app version data to file"""
    try:
        with open(APP_VERSION_FILE, 'w') as f:
            json.dump(version_data, f, indent=2)
        return True
    except Exception as e:
        logger.error(f"Error saving app version: {e}")
        return False

# Initialize app version data
app_version_data = load_app_version()

def keep_alive():
    """Run Flask app in a separate thread for keep-alive"""
    t = Thread(target=lambda: app.run(host='0.0.0.0', port=8080, use_reloader=False))
    t.start()

class WinbuScraper:
    def __init__(self):
        self.base_url = "https://winbu.tv"
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Referer': 'https://winbu.tv/'
        }

    def get_page(self, url):
        """Fetch page content with error handling and retry logic"""
        max_retries = 3
        retry_delay = 2

        for attempt in range(max_retries):
            try:
                response = requests.get(url, headers=self.headers, timeout=10)
                response.raise_for_status()
                return response.text
            except requests.exceptions.RequestException as e:
                logger.error(f"Error fetching {url}: {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to fetch {url} after {max_retries} Wattempts")
                    return None

    def resolve_krakenfiles_url(self, url):
        """Extract direct stream URL in .mp4 or .m3u8 format from Krakenfiles link"""
        try:
            html = self.get_page(url)
            if not html:
                logger.warning(f"Failed to fetch Krakenfiles page: {url}")
                return None

            soup = BeautifulSoup(html, 'html.parser')

            # Cari tag <video> dan <source>
            video_tag = soup.find('video')
            if video_tag:
                source = video_tag.find('source')
                if source and source.get('src'):
                    stream_url = source['src']
                    # Periksa tipe dari tag <source>
                    source_type = source.get('type', '').lower()
                    if source_type == 'video/mp4' or source_type == 'application/vnd.apple.mpegurl':
                        logger.info(f"Found Krakenfiles video source: {stream_url}")
                        return stream_url
                    # Verifikasi Content-Type sebagai cadangan
                    response = requests.head(stream_url, headers=self.headers, allow_redirects=True, timeout=10)
                    content_type = response.headers.get('Content-Type', '').lower()
                    if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                        logger.info(f"Found Krakenfiles video source (Content-Type: {content_type}): {stream_url}")
                        return stream_url
                    logger.warning(f"Invalid Content-Type for Krakenfiles video source: {content_type}")

            # Cari iframe embed
            embed_iframe = soup.find('iframe', src=re.compile(r'https?://krakenfiles\.com/embed-video'))
            if embed_iframe and embed_iframe.get('src'):
                embed_url = embed_iframe['src']
                embed_html = self.get_page(embed_url)
                if embed_html:
                    embed_soup = BeautifulSoup(embed_html, 'html.parser')
                    # Cari tag <video> di halaman embed
                    embed_video_tag = embed_soup.find('video')
                    if embed_video_tag:
                        source = embed_video_tag.find('source')
                        if source and source.get('src'):
                            stream_url = source['src']
                            source_type = source.get('type', '').lower()
                            if source_type == 'video/mp4' or source_type == 'application/vnd.apple.mpegurl':
                                logger.info(f"Found Krakenfiles embed video source: {stream_url}")
                                return stream_url
                            response = requests.head(stream_url, headers=self.headers, allow_redirects=True, timeout=10)
                            content_type = response.headers.get('Content-Type', '').lower()
                            if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                                logger.info(f"Found Krakenfiles embed video source (Content-Type: {content_type}): {stream_url}")
                                return stream_url
                            logger.warning(f"Invalid Content-Type for Krakenfiles embed video source: {content_type}")

                    # Cari URL di script pada halaman embed
                    scripts = embed_soup.find_all('script')
                    for script in scripts:
                        if script.string:
                            matches = re.findall(r'(https?://[^\s\'\"]+\.(mp4|m3u8))', script.string)
                            if matches:
                                stream_url = matches[0][0]
                                response = requests.head(stream_url, headers=self.headers, allow_redirects=True, timeout=10)
                                content_type = response.headers.get('Content-Type', '').lower()
                                if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                                    logger.info(f"Found Krakenfiles stream URL in embed script (Content-Type: {content_type}): {stream_url}")
                                    return stream_url
                                logger.warning(f"Invalid Content-Type for Krakenfiles embed script URL: {content_type}")

            # Cari URL di script pada halaman utama sebagai cadangan
            scripts = soup.find_all('script')
            for script in scripts:
                if script.string:
                    matches = re.findall(r'(https?://[^\s\'\"]+\.(mp4|m3u8))', script.string)
                    if matches:
                        stream_url = matches[0][0]
                        response = requests.head(stream_url, headers=self.headers, allow_redirects=True, timeout=10)
                        content_type = response.headers.get('Content-Type', '').lower()
                        if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                            logger.info(f"Found Krakenfiles stream URL in main page script (Content-Type: {content_type}): {stream_url}")
                            return stream_url
                        logger.warning(f"Invalid Content-Type for Krakenfiles main page script URL: {content_type}")

            logger.warning(f"No .mp4 or .m3u8 URL found for Krakenfiles: {url}")
            return None
        except Exception as e:
            logger.error(f"Error resolving Krakenfiles URL {url}: {e}")
            return None

    def resolve_mega_url(self, url):
        """Extract direct stream URL in .mp4 or .m3u8 format from Mega link"""
        try:
            html = self.get_page(url)
            if not html:
                logger.warning(f"Failed to fetch Mega page: {url}")
                return None

            soup = BeautifulSoup(html, 'html.parser')
            video_tag = soup.find('video')
            if video_tag:
                source = video_tag.find('source')
                if source and source.get('src'):
                    stream_url = source['src']
                    source_type = source.get('type', '').lower()
                    if source_type == 'video/mp4' or source_type == 'application/vnd.apple.mpegurl':
                        logger.info(f"Found Mega video source: {stream_url}")
                        return stream_url
                    response = requests.head(stream_url, headers=self.headers, allow_redirects=True, timeout=10)
                    content_type = response.headers.get('Content-Type', '').lower()
                    if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                        logger.info(f"Found Mega video source (Content-Type: {content_type}): {stream_url}")
                        return stream_url
                    logger.warning(f"Invalid Content-Type for Mega video source: {content_type}")

            # Cari URL streaming di script
            scripts = soup.find_all('script')
            for script in scripts:
                if script.string:
                    matches = re.findall(r'(https?://[^\s\'\"]+\.(mp4|m3u8))', script.string)
                    if matches:
                        stream_url = matches[0][0]
                        response = requests.head(stream_url, headers=self.headers, allow_redirects=True, timeout=10)
                        content_type = response.headers.get('Content-Type', '').lower()
                        if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                            logger.info(f"Found Mega direct URL in script (Content-Type: {content_type}): {stream_url}")
                            return stream_url
                        logger.warning(f"Invalid Content-Type for Mega script URL: {content_type}")

            logger.warning(f"No .mp4 or .m3u8 URL found for Mega: {url}")
            return None
        except Exception as e:
            logger.error(f"Error resolving Mega URL {url}: {e}")
            return None

    def resolve_pixeldrain_url(self, url):
        """Extract direct stream URL in .mp4 or .m3u8 format from PixelDrain link"""
        try:
            if 'pixeldrain.com/u/' in url:
                file_id = url.split('/u/')[-1].split('?')[0]
                direct_url = f"https://pixeldrain.com/api/file/{file_id}"
                response = requests.head(direct_url, headers=self.headers, allow_redirects=True, timeout=10)
                if response.status_code == 200:
                    content_type = response.headers.get('Content-Type', '').lower()
                    if 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type or 'application/octet-stream' in content_type:
                        logger.info(f"Found PixelDrain direct URL (Content-Type: {content_type}): {direct_url}")
                        return direct_url
                    logger.warning(f"PixelDrain URL not streamable: {direct_url} (Content-Type: {content_type})")
                else:
                    logger.warning(f"Failed to access PixelDrain URL: {direct_url} (Status: {response.status_code})")
                return None
            logger.warning(f"Invalid PixelDrain URL format: {url}")
            return None
        except Exception as e:
            logger.error(f"Error resolving PixelDrain URL {url}: {e}")
            return None

    def get_top_anime(self):
        """Extract top anime list from homepage"""
        logger.info("Fetching top anime list...")
        html = self.get_page(self.base_url)
        if not html:
            return []

        soup = BeautifulSoup(html, 'html.parser')
        top_anime_section = soup.find('div', class_='movies-list-wrap mlw-category')

        top_anime_list = []
        if top_anime_section:
            anime_items = top_anime_section.select('.ml-item')

            for item in anime_items:
                try:
                    link_element = item.find('a', class_='ml-mask')
                    if not link_element:
                        continue

                    title = link_element.get('title', '')
                    url = link_element.get('href', '')

                    img_element = link_element.find('img')
                    image_url = img_element.get('src', '') if img_element else ''

                    rating_element = link_element.find('span', class_='mli-mvi')
                    rating = rating_element.text.strip() if rating_element else 'N/A'

                    rank_element = link_element.find('span', class_='mli-topten')
                    rank = rank_element.text.strip() if rank_element else 'N/A'

                    anime_data = {
                        'title': title,
                        'url': url,
                        'image_url': image_url,
                        'rating': rating,
                        'rank': rank
                    }

                    top_anime_list.append(anime_data)
                except Exception as e:
                    logger.error(f"Error parsing anime item: {e}")

        logger.info(f"Found {len(top_anime_list)} top anime")
        return top_anime_list

    def get_latest_anime(self, page=1):
        """Extract latest anime releases from homepage with pagination support"""
        logger.info(f"Fetching latest anime releases from page {page}...")
        url = f"{self.base_url}/animedonghua/" if page == 1 else f"{self.base_url}/animedonghua/page/{page}/"

        html = self.get_page(url)
        if not html:
            return {
                'anime_list': [],
                'current_page': page,
                'total_pages': 1
            }

        soup = BeautifulSoup(html, 'html.parser')
        latest_anime_list = []

        try:
            anime_items = soup.select('.ml-item-anime')
            if not anime_items:
                anime_items = soup.select('.ml-item')

            for item in anime_items:
                try:
                    link_element = item.find('a', class_='ml-mask')
                    if not link_element:
                        continue

                    title = link_element.get('title', '')
                    url = link_element.get('href', '')

                    img_element = link_element.find('img')
                    image_url = img_element.get('src', '') if img_element else ''

                    episode_element = link_element.find('span', class_='mli-episode')
                    episode = episode_element.text.strip() if episode_element else 'N/A'

                    views_element = link_element.find('span', class_='mli-mvi')
                    views = views_element.text.strip() if views_element else 'N/A'

                    duration_element = link_element.find('span', class_='mli-waktu')
                    duration = duration_element.text.strip() if duration_element else 'N/A'

                    rank_element = link_element.find('span', class_='mli-topten')
                    rank = None
                    if rank_element and rank_element.find('b'):
                        rank = rank_element.find('b').text.strip()

                    anime_data = {
                        'title': title,
                        'url': url,
                        'image_url': image_url,
                        'episode': episode,
                        'views': views,
                        'duration': duration,
                        'rank': rank
                    }

                    latest_anime_list.append(anime_data)
                except Exception as e:
                    logger.error(f"Error parsing latest anime item: {e}")

            pagination = soup.find('div', id='pagination')
            total_pages = 1
            if pagination:
                page_links = pagination.select('ul.pagination li a')
                if page_links:
                    try:
                        page_numbers = [int(link.text) for link in page_links if link.text.isdigit()]
                        if page_numbers:
                            total_pages = max(page_numbers)
                    except ValueError:
                        total_pages = 1

            logger.info(f"Found {len(latest_anime_list)} latest anime releases on page {page}")
            return {
                'anime_list': latest_anime_list,
                'current_page': page,
                'total_pages': total_pages
            }

        except Exception as e:
            logger.error(f"Error parsing anime list: {e}")
            return {
                'anime_list': [],
                'current_page': page,
                'total_pages': 1
            }

    def get_anime_details(self, url):
        """Extract detailed information about an anime"""
        logger.info(f"Fetching anime details from {url}...")
        html = self.get_page(url)
        if not html:
            logger.error("Failed to fetch page content")
            return {}

        soup = BeautifulSoup(html, 'html.parser')

        try:
            title = 'Unknown Title'
            title_container = soup.find('div', class_='list-title')
            if title_container:
                title_element = title_container.find('h2')
                if title_element:
                    title = title_element.text.strip()
                    logger.info(f"Title found in list-title: {title}")
                else:
                    logger.warning("No <h2> found in list-title container")

            if title == 'Unknown Title':
                judul_element = soup.select_one('.mli-info .judul')
                if judul_element:
                    title = judul_element.text.strip()
                    logger.info(f"Title found in mli-info judul: {title}")
                else:
                    logger.warning("No judul element found in mli-info")

            if title == 'Unknown Title':
                meta_title = soup.find('meta', property='og:title')
                if meta_title and meta_title.get('content'):
                    title = meta_title['content'].strip()
                    logger.info(f"Title found in meta og:title: {title}")
                else:
                    first_h2 = soup.find('h2')
                    if first_h2:
                        title = first_h2.text.strip()
                        logger.info(f"Title found in first h2: {title}")
                    else:
                        logger.warning("No title found in any fallback methods")

            img_element = soup.select_one('.mli-thumb')
            image_url = img_element.get('src', '') if img_element else ''
            logger.debug(f"Image URL: {image_url}")

            rating_element = soup.find('span', itemprop='ratingValue')
            rating = rating_element.text.strip() if rating_element else 'N/A'
            logger.debug(f"Rating: {rating}")

            date_element = soup.find('div', class_='mli-mvi', string=lambda text: text and 'calendar' in text)
            release_date = date_element.text.replace('calendar', '').strip() if date_element else 'N/A'
            logger.debug(f"Release Date: {release_date}")

            genre_elements = soup.find_all('div', class_='mli-mvi')
            genres = []
            for element in genre_elements:
                if 'Genre' in element.text:
                    genre_links = element.find_all('a')
                    genres = [link.text.strip() for link in genre_links if link.text.strip()]
                    break
            logger.debug(f"Genres: {genres}")

            synopsis_element = soup.find('div', class_='mli-desc')
            synopsis = synopsis_element.text.strip() if synopsis_element else 'No synopsis available'
            logger.debug(f"Synopsis: {synopsis[:100]}...")

            episodes = []
            episodes_section = soup.find('div', class_='les-content')
            if episodes_section:
                episode_links = episodes_section.find_all('a')
                for link in episode_links:
                    episode_title = link.text.strip()
                    episode_url = link.get('href', '')
                    episodes.append({
                        'title': episode_title,
                        'url': episode_url
                    })
                logger.debug(f"Found {len(episodes)} episodes")

            anime_details = {
                'title': title,
                'image_url': image_url,
                'rating': rating,
                'release_date': release_date,
                'genres': genres,
                'synopsis': synopsis,
                'episodes': episodes
            }

            logger.info(f"Successfully extracted details for {title}")
            return anime_details

        except Exception as e:
            logger.error(f"Error extracting anime details: {e}")
            return {}

    def get_ajax_stream_url(self, post_id, nume, stream_type="urliframe"):
        """Get streaming URL from AJAX endpoint"""
        try:
            ajax_url = f"{self.base_url}/wp-admin/admin-ajax.php"
            ajax_data = {
                'action': 'doo_player_ajax',
                'post': post_id,
                'nume': nume,
                'type': stream_type
            }
            
            response = requests.post(ajax_url, data=ajax_data, headers=self.headers, timeout=10)
            if response.status_code == 200:
                try:
                    json_response = response.json()
                    if 'embed_url' in json_response:
                        embed_url = json_response['embed_url']
                        logger.info(f"Found AJAX embed URL: {embed_url}")
                        return embed_url
                except json.JSONDecodeError:
                    # Sometimes the response is just the URL
                    if response.text.startswith('http'):
                        logger.info(f"Found AJAX direct URL: {response.text}")
                        return response.text.strip()
            
            logger.warning(f"Failed to get AJAX stream URL for post {post_id}, nume {nume}")
            return None
        except Exception as e:
            logger.error(f"Error getting AJAX stream URL: {e}")
            return None

    def resolve_filemoon_url(self, url):
        """Extract direct stream URL from Filemoon link"""
        try:
            html = self.get_page(url)
            if not html:
                logger.warning(f"Failed to fetch Filemoon page: {url}")
                return None

            soup = BeautifulSoup(html, 'html.parser')
            
            # Cari script yang mengandung eval atau file URL
            scripts = soup.find_all('script')
            for script in scripts:
                if script.string:
                    # Cari pattern untuk file URL
                    if 'eval(' in script.string or 'file:' in script.string:
                        # Cari URL .mp4 atau .m3u8
                        matches = re.findall(r'["\']([^"\'\']+\.(mp4|m3u8))["\']', script.string)
                        if matches:
                            stream_url = matches[0][0]
                            if stream_url.startswith('http'):
                                logger.info(f"Found Filemoon stream URL: {stream_url}")
                                return stream_url
            
            logger.warning(f"No stream URL found for Filemoon: {url}")
            return None
        except Exception as e:
            logger.error(f"Error resolving Filemoon URL {url}: {e}")
            return None

    def resolve_vidhidepro_url(self, url):
        """Extract direct stream URL from VidHidePro link"""
        try:
            html = self.get_page(url)
            if not html:
                logger.warning(f"Failed to fetch VidHidePro page: {url}")
                return None

            soup = BeautifulSoup(html, 'html.parser')
            
            # Cari tag video atau source
            video_tag = soup.find('video')
            if video_tag:
                source = video_tag.find('source')
                if source and source.get('src'):
                    stream_url = source['src']
                    logger.info(f"Found VidHidePro video source: {stream_url}")
                    return stream_url
            
            # Cari di script
            scripts = soup.find_all('script')
            for script in scripts:
                if script.string:
                    matches = re.findall(r'["\']([^"\'\']+\.(mp4|m3u8))["\']', script.string)
                    if matches:
                        stream_url = matches[0][0]
                        if stream_url.startswith('http'):
                            logger.info(f"Found VidHidePro stream URL: {stream_url}")
                            return stream_url
            
            logger.warning(f"No stream URL found for VidHidePro: {url}")
            return None
        except Exception as e:
            logger.error(f"Error resolving VidHidePro URL {url}: {e}")
            return None

    def get_episode_streams(self, url):
        """Extract streaming links for an episode, prioritizing .mp4 or .m3u8 formats with PixelDrain as the preferred host"""
        logger.info(f"Fetching episode streams from {url}...")
        html = self.get_page(url)
        if not html:
            return {}

        soup = BeautifulSoup(html, 'html.parser')

        try:
            # Prioritize title from list-title section
            title = 'Unknown Episode'
            title_container = soup.find('div', class_='list-title')
            if title_container:
                title_element = title_container.find('h2')
                if title_element:
                    title = title_element.text.strip()
                    logger.info(f"Title found in list-title: {title}")
                else:
                    logger.warning("No <h2> found in list-title container")

            # Fallback to meta og:title
            if title == 'Unknown Episode':
                meta_title = soup.find('meta', property='og:title')
                if meta_title and meta_title.get('content'):
                    title = meta_title['content'].strip()
                    logger.info(f"Title found in meta og:title: {title}")

            # Final fallback to first h2 with 'Episode' in text
            if title == 'Unknown Episode':
                title_element = soup.find('h2', string=lambda text: text and 'Episode' in text)
                if title_element:
                    title = title_element.text.strip()
                    logger.info(f"Title found in h2 with Episode: {title}")

            # Cari iframe stream URL dari movieplay
            iframe_element = soup.select_one('.movieplay iframe')
            stream_url = None
            if iframe_element and iframe_element.get('src'):
                iframe_src = iframe_element['src']
                response = requests.head(iframe_src, headers=self.headers, allow_redirects=True, timeout=10)
                final_url = response.url
                content_type = response.headers.get('Content-Type', '').lower()
                if final_url.endswith(('.mp4', '.m3u8')) or 'video' in content_type or 'application/vnd.apple.mpegurl' in content_type:
                    stream_url = final_url
                    logger.info(f"Found iframe stream URL: {stream_url}")

            # Cari player options untuk AJAX requests
            player_options = []
            ajax_stream_urls = []
            player_section = soup.find('div', class_='player-modes')
            if player_section:
                option_elements = player_section.select('.east_player_option')
                for option in option_elements:
                    option_text = option.find('span')
                    if option_text:
                        player_name = option_text.text.strip()
                        player_options.append(player_name)
                        
                        # Ambil data untuk AJAX request
                        post_id = option.get('data-post')
                        nume = option.get('data-nume')
                        stream_type = option.get('data-type', 'urliframe')
                        
                        if post_id and nume:
                            ajax_url = self.get_ajax_stream_url(post_id, nume, stream_type)
                            if ajax_url:
                                ajax_stream_urls.append({
                                    'player': player_name,
                                    'url': ajax_url
                                })
                                
                                # Jika belum ada stream_url, gunakan yang pertama
                                if not stream_url:
                                    stream_url = ajax_url
                                    logger.info(f"Using AJAX stream URL as primary: {stream_url}")

            download_links = {}
            direct_stream_urls = []
            all_stream_sources = []
            download_section = soup.find('div', id='downloadb')

            if download_section:
                quality_sections = download_section.find_all('li')

                for section in quality_sections:
                    quality_text = section.find('strong')
                    if not quality_text:
                        continue

                    quality = quality_text.text.strip()
                    links = []

                    link_elements = section.find_all('a')
                    for link in link_elements:
                        host = link.text.strip()
                        download_url = link.get('href', '')
                        direct_url = None

                        # Resolve berbagai jenis host
                        if 'filemoon' in host.lower() or 'filemoon' in download_url.lower():
                            direct_url = self.resolve_filemoon_url(download_url)
                        elif 'vidhidepro' in host.lower() or 'vidhidepro' in download_url.lower():
                            direct_url = self.resolve_vidhidepro_url(download_url)
                        elif 'krakenfiles' in host.lower() or 'krakenfiles' in download_url.lower():
                            direct_url = self.resolve_krakenfiles_url(download_url)
                        elif 'mega.' in host.lower() or 'mega.' in download_url.lower():
                            direct_url = self.resolve_mega_url(download_url)
                        elif 'pixeldrain' in host.lower() or 'pixeldrain' in download_url.lower():
                            direct_url = self.resolve_pixeldrain_url(download_url)
                        elif 'hellabyte' in host.lower() or 'hellabyte' in download_url.lower():
                            # Hellabyte biasanya direct link
                            direct_url = download_url
                        elif 'buzzheavier' in host.lower() or 'buzzheavier' in download_url.lower():
                            # Buzzheavier perlu resolving khusus
                            direct_url = download_url  # Sementara gunakan direct

                        if direct_url:
                            direct_stream_urls.append({
                                'quality': quality,
                                'host': host if host else 'Unknown',
                                'url': direct_url
                            })
                            all_stream_sources.append(direct_url)

                        if download_url:
                            links.append({
                                'host': host,
                                'url': download_url
                            })

                    download_links[quality] = links

            # Gunakan direct_stream_urls sebagai fallback jika tidak ada stream_url
            if not stream_url and direct_stream_urls:
                # Prioritas: Filemoon > PixelDrain > lainnya
                for stream in direct_stream_urls:
                    if 'filemoon' in stream['host'].lower():
                        stream_url = stream['url']
                        logger.info(f"Using Filemoon direct stream URL as fallback: {stream_url}")
                        break
                
                if not stream_url:
                    for stream in direct_stream_urls:
                        if 'pixeldrain' in stream['host'].lower():
                            stream_url = stream['url']
                            logger.info(f"Using PixelDrain direct stream URL as fallback: {stream_url}")
                            break
                
                # Jika masih tidak ada, ambil URL pertama
                if not stream_url:
                    stream_url = direct_stream_urls[0]['url']
                    logger.info(f"Using first direct stream URL as fallback: {stream_url}")

            # Tambahkan AJAX URLs ke all_stream_sources
            for ajax_stream in ajax_stream_urls:
                all_stream_sources.append(ajax_stream['url'])

            # Cari URL tambahan di script
            scripts = soup.find_all('script')
            for script in scripts:
                if script.string:
                    matches = re.findall(r'(https?://[^\s\'\"]+\.(mp4|m3u8))', script.string)
                    for match in matches:
                        all_stream_sources.append(match[0])

            # Deduplikasi all_stream_sources
            all_stream_sources = list(dict.fromkeys(all_stream_sources))

            # Tambahkan stream_url ke all_stream_sources jika ada
            if stream_url:
                all_stream_sources.insert(0, stream_url)

            logger.info(f"Stream URL: {stream_url}")
            logger.info(f"Direct stream URLs: {json.dumps(direct_stream_urls, indent=2)}")
            logger.info(f"AJAX stream URLs: {json.dumps(ajax_stream_urls, indent=2)}")
            logger.info(f"All stream sources: {all_stream_sources}")

            episode_data = {
                'title': title,
                'stream_url': stream_url,
                'download_links': download_links,
                'player_options': player_options,
                'direct_stream_urls': direct_stream_urls,
                'ajax_stream_urls': ajax_stream_urls,
                'all_stream_sources': all_stream_sources
            }

            logger.info(f"Successfully extracted streams for {title}")
            return episode_data

        except Exception as e:
            logger.error(f"Error extracting episode streams: {e}")
            return {}

    def search_anime(self, query):
        """Search for anime by title"""
        logger.info(f"Searching for anime: {query}")
        encoded_query = urllib.parse.quote(query)
        search_url = f"{self.base_url}/?s={encoded_query}"

        html = self.get_page(search_url)
        if not html:
            return []

        soup = BeautifulSoup(html, 'html.parser')
        search_results = []

        try:
            result_items = soup.select('.a-item')
            if not result_items:
                result_items = soup.select('.ml-item')
            if not result_items:
                result_items = soup.select('.movies-list-full div[class*="item"]')

            for item in result_items:
                try:
                    link_element = item.find('a', class_='ml-mask')
                    if not link_element:
                        continue

                    title = link_element.get('title', '')
                    url = link_element.get('href', '')

                    img_element = link_element.find('img')
                    image_url = img_element.get('src', '') if img_element else ''

                    anime_info = {
                        'title': title,
                        'url': url,
                        'image_url': image_url
                    }

                    type_element = item.find('li', class_='mli-mvi-x')
                    if type_element:
                        anime_info['type'] = type_element.text.strip()

                    season_element = item.select_one('li.mli-mvi-x a[href*="/season/"]')
                    if season_element:
                        anime_info['season'] = season_element.text.strip()

                    desc_element = item.find('li', class_='mli-desc')
                    if desc_element:
                        anime_info['description'] = desc_element.text.strip()

                    search_results.append(anime_info)
                except Exception as e:
                    logger.error(f"Error parsing search result item: {e}")

            if not search_results:
                logger.info("No results found with standard parsing, trying alternative approach")
                all_links = soup.select('a.ml-mask')
                for link in all_links:
                    title = link.get('title', '')
                    url = link.get('href', '')
                    if title and url and '/anime/' in url:
                        img_element = link.find('img')
                        image_url = img_element.get('src', '') if img_element else ''
                        search_results.append({
                            'title': title,
                            'url': url,
                            'image_url': image_url
                        })

            logger.info(f"Found {len(search_results)} results for '{query}'")
            if search_results:
                logger.info(f"First result: {json.dumps(search_results[0])}")

            return search_results

        except Exception as e:
            logger.error(f"Error searching for anime: {e}")
            logger.error(f"Search URL: {search_url}")
            logger.error(f"HTML snippet: {html[:500]}..." if html else "No HTML content")
            return []

    def get_release_schedule(self, day=None):
        """Extract anime release schedule for a specific day or all days"""
        logger.info(f"Fetching release schedule for day: {day if day else 'all days'}...")
        schedule_url = f"{self.base_url}/jadwal-rilis"
        html = self.get_page(schedule_url)
        if not html:
            return {} if not day else []

        soup = BeautifulSoup(html, 'html.parser')
        schedule_data = {}

        # Get all available days from the UI
        days_section = soup.find('div', id='the-days')
        if not days_section:
            logger.error("Days section not found")
            return {} if not day else []

        day_elements = days_section.find_all('div', class_='east_days_option')
        days = []
        day_data_values = {}  # Store data-day values for each day

        # Find current active day
        default_day = None

        for elem in day_elements:
            day_name = elem.find('span').text.strip().lower() if elem.find('span') else None
            if day_name:
                days.append(day_name)
                # Store the data-day attribute value for API calls
                day_data_value = elem.get('data-day', day_name.lower())
                day_data_values[day_name] = day_data_value

                if elem.get('class') and 'on' in elem.get('class'):
                    default_day = day_name

        # Process each day or just the specified day
        for day_name in days:
            if day and day_name.lower() != day.lower():
                continue

            day_schedule = []
            api_day_value = day_data_values.get(day_name, day_name.lower())

            # Try AJAX endpoint first
            ajax_url = f"{self.base_url}/wp-json/custom/v1/all-schedule"
            try:
                logger.info(f"Fetching schedule via AJAX for day: {day_name} (parameter: {api_day_value})")
                response = requests.get(
                    ajax_url,
                    headers=self.headers,
                    params={'day': api_day_value, 'perpage': 20},
                    timeout=10
                )

                if response.status_code == 200:
                    try:
                        schedule_items = response.json()
                        if isinstance(schedule_items, list) and len(schedule_items) > 0:
                            logger.info(f"AJAX fetched {len(schedule_items)} items for {day_name}")
                            for item in schedule_items:
                                try:
                                    schedule_data_item = {
                                        'title': item.get('title', 'Unknown Title'),
                                        'url': item.get('url', ''),
                                        'time': item.get('east_time', 'N/A'),
                                        'rating': str(item.get('east_score', 'N/A')),
                                        'image_url': item.get('featured_img_src', ''),
                                        'day': day_name.capitalize()
                                    }
                                    day_schedule.append(schedule_data_item)
                                except Exception as e:
                                    logger.error(f"Error parsing AJAX schedule item for {day_name}: {e}")
                        else:
                            logger.warning(f"AJAX returned empty or invalid result for {day_name}")
                    except ValueError as e:
                        logger.warning(f"Failed to parse AJAX JSON response for {day_name}: {e}")
                else:
                    logger.warning(f"AJAX request failed with status {response.status_code} for {day_name}")

            except Exception as e:
                logger.warning(f"AJAX request failed for {day_name}: {e}, falling back to HTML parsing")

            # Fallback to HTML parsing if AJAX fails or returns no data
            if not day_schedule:
                logger.info(f"Falling back to HTML parsing for {day_name}")

                # If we're looking for a day that isn't currently displayed, we need to parse the day's content
                if day_name.lower() == default_day.lower():
                    # Parse the currently displayed day's schedule
                    try:
                        schedule_section = soup.find('div', class_='result-schedule')
                        if schedule_section:
                            anime_items = schedule_section.find_all('div', class_='ml-item')

                            for item in anime_items:
                                try:
                                    link_element = item.find('a', class_='ml-mask')
                                    if not link_element:
                                        continue

                                    title = link_element.get('title', 'Unknown Title')
                                    url = link_element.get('href', '')

                                    img_element = link_element.find('img')
                                    image_url = img_element.get('src', '') if img_element else ''

                                    rating_element = item.find('div', class_='mli-mvi')
                                    rating = rating_element.text.strip() if rating_element else 'N/A'
                                    rating = rating.replace('★', '').strip() if '★' in rating else rating
                                    rating = rating.replace('i class="fa fa-star" aria-hidden="true"></i>', '').strip()

                                    time_element = item.find('span', class_='mli-waktu')
                                    time = time_element.text.strip() if time_element else 'N/A'
                                    time = time.replace('🕒', '').strip() if '🕒' in time else time
                                    time = time.replace('i class="fa fa-clock"></i>', '').strip()

                                    schedule_data_item = {
                                        'title': title,
                                        'url': url,
                                        'time': time,
                                        'rating': rating,
                                        'image_url': image_url,
                                        'day': day_name.capitalize()
                                    }
                                    day_schedule.append(schedule_data_item)
                                except Exception as e:
                                    logger.error(f"Error parsing HTML schedule item for {day_name}: {e}")
                    except Exception as e:
                        logger.error(f"Error parsing schedule HTML for {day_name}: {e}")
                else:
                    logger.warning(f"Cannot parse HTML for {day_name} as it's not the currently active day")

            schedule_data[day_name.capitalize()] = day_schedule

        if day:
            return schedule_data.get(day.capitalize(), [])
        return schedule_data

    def get_genres(self):
        """Extract genres list from homepage sidebar"""
        logger.info("Fetching genres list...")
        html = self.get_page(self.base_url)
        if not html:
            return []

        soup = BeautifulSoup(html, 'html.parser')
        genres_list = []

        try:
            # Find the sidebar with genres
            sidebar = soup.find('aside', id='sidebar')
            if sidebar:
                # Find the genres section
                genres_section = sidebar.find('ul', class_='years genres noscroll')
                if genres_section:
                    genre_items = genres_section.find_all('li')
                    
                    for item in genre_items:
                        try:
                            link_element = item.find('a')
                            if link_element:
                                genre_name = link_element.text.strip()
                                genre_url = link_element.get('href', '')
                                
                                # Extract count from span if available
                                count_span = link_element.find('span')
                                count = 0
                                if count_span:
                                    count_text = count_span.text.strip()
                                    # Extract number from text like " (601)"
                                    count_match = re.search(r'\((\d+)\)', count_text)
                                    if count_match:
                                        count = int(count_match.group(1))
                                    # Remove count from genre name
                                    genre_name = genre_name.replace(count_text, '').strip()
                                
                                genre_data = {
                                    'name': genre_name,
                                    'url': genre_url,
                                    'count': count
                                }
                                
                                genres_list.append(genre_data)
                        except Exception as e:
                            logger.error(f"Error parsing genre item: {e}")
                else:
                    logger.warning("Genres section not found in sidebar")
            else:
                logger.warning("Sidebar not found")
                
        except Exception as e:
            logger.error(f"Error parsing genres: {e}")

        logger.info(f"Found {len(genres_list)} genres")
        return genres_list

    def get_genre_content(self, genre_url, page=1):
        """Extract content from genre page"""
        logger.info(f"Fetching genre content from: {genre_url}, page: {page}")
        
        # Construct the URL with page parameter if needed
        if page > 1:
            if genre_url.endswith('/'):
                url = f"{genre_url}page/{page}/"
            else:
                url = f"{genre_url}/page/{page}/"
        else:
            url = genre_url
            
        html = self.get_page(url)
        if not html:
            return {'content': [], 'current_page': page, 'total_pages': 1}

        soup = BeautifulSoup(html, 'html.parser')
        content_list = []
        
        try:
            # Find the movies list container
            movies_container = soup.find('div', class_='movies-list')
            if movies_container:
                # Find all movie items
                movie_items = movies_container.find_all('div', class_='ml-item')
                
                for item in movie_items:
                    try:
                        link_element = item.find('a', class_='ml-mask')
                        if link_element:
                            title = link_element.get('title', '').strip()
                            url = link_element.get('href', '')
                            
                            # Get image
                            img_element = item.find('img', class_='mli-thumb')
                            image_url = img_element.get('src', '') if img_element else ''
                            
                            # Get additional info
                            info_element = item.find('span', class_='mli-info')
                            views = '0'
                            duration = ''
                            
                            if info_element:
                                # Get views
                                views_element = info_element.find('span', class_='mli-mvi')
                                if views_element:
                                    views_text = views_element.text.strip()
                                    views = re.sub(r'[^0-9]', '', views_text) or '0'
                                
                                # Get duration/time
                                time_element = info_element.find('span', class_='mli-waktu')
                                if time_element:
                                    duration = time_element.text.strip().replace('\uf017', '').strip()
                            
                            # Determine content type based on URL
                            content_type = 'anime' if '/anime/' in url else 'movie'
                            if '/series/' in url:
                                content_type = 'series'
                            elif '/film/' in url:
                                content_type = 'movie'
                            
                            content_data = {
                                'title': title,
                                'url': url,
                                'image_url': image_url,
                                'views': views,
                                'duration': duration,
                                'type': content_type
                            }
                            
                            content_list.append(content_data)
                    except Exception as e:
                        logger.error(f"Error parsing content item: {e}")
            
            # Get pagination info
            current_page = page
            total_pages = 1
            
            pagination = soup.find('div', id='pagination')
            if pagination:
                page_links = pagination.find_all('a', class_='page')
                if page_links:
                    # Find the highest page number
                    page_numbers = []
                    for link in page_links:
                        href = link.get('href', '')
                        page_match = re.search(r'/page/(\d+)/', href)
                        if page_match:
                            page_numbers.append(int(page_match.group(1)))
                    
                    if page_numbers:
                        total_pages = max(page_numbers)
                        
        except Exception as e:
            logger.error(f"Error parsing genre content: {e}")
        
        logger.info(f"Found {len(content_list)} content items on page {current_page}")
        return {
            'content': content_list,
            'current_page': current_page,
            'total_pages': total_pages
        }

class KomikindoScraper:
    def __init__(self):
        self.base_url = "https://komikindo.ch"
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Referer': 'https://komikindo.ch/'
        }

    def get_page(self, url):
        """Fetch page content with error handling, retry logic, and user-agent rotation"""
        max_retries = 3
        retry_delay = 2
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0',
        ]

        for attempt in range(max_retries):
            try:
                # Rotate user-agent
                self.headers['User-Agent'] = user_agents[attempt % len(user_agents)]
                logger.info(f"Attempt {attempt + 1} to fetch URL: {url} with User-Agent: {self.headers['User-Agent']}")
                time.sleep(1)
                response = requests.get(url, headers=self.headers, timeout=10)
                response.raise_for_status()
                logger.info(f"Successfully fetched URL: {url}, Status Code: {response.status_code}")
                
                # Check if the response is HTML
                content_type = response.headers.get('Content-Type', '')
                if 'text/html' not in content_type.lower():
                    logger.warning(f"Unexpected Content-Type: {content_type} for URL: {url}")
                    return None

                return response.text
            except requests.exceptions.RequestException as e:
                logger.error(f"Error fetching {url}: {e}")
                if attempt < max_retries - 1:
                    logger.info(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    logger.error(f"Failed to fetch {url} after {max_retries} attempts")
                    return None

    def get_latest_comics(self, page=1):
        """Extract latest comic releases from Komikindo with pagination support"""
        logger.info(f"Fetching latest comics from page {page}...")
        url = f"{self.base_url}/komik-terbaru/" if page == 1 else f"{self.base_url}/komik-terbaru/page/{page}/"

        html = self.get_page(url)
        if not html:
            return {
                'comic_list': [],
                'current_page': page,
                'total_pages': 1
            }

        soup = BeautifulSoup(html, 'html.parser')
        comic_list = []

        try:
            comic_items = soup.select('.animepost')

            for item in comic_items:
                try:
                    link_element = item.find('a', itemprop='url')
                    if not link_element:
                        continue

                    title = link_element.get('title', '').replace('Komik ', '')
                    url = link_element.get('href', '')

                    img_element = item.find('img', itemprop='image')
                    image_url = img_element.get('src', '') if img_element else ''

                    type_element = item.find('span', class_=re.compile(r'typeflag'))
                    comic_type = type_element.get('class', [''])[-1] if type_element else 'Unknown'

                    color_label = item.find('div', class_='warnalabel')
                    is_colored = bool(color_label)

                    hot_label = item.find('span', class_='hot')
                    is_hot = bool(hot_label)

                    chapter_element = item.find('div', class_='lsch').find('a')
                    chapter = chapter_element.text.strip() if chapter_element else 'N/A'
                    chapter_url = chapter_element.get('href', '') if chapter_element else ''

                    update_time = item.find('span', class_='datech')
                    update_time = update_time.text.strip() if update_time else 'N/A'

                    comic_data = {
                        'title': title,
                        'url': url,
                        'image_url': image_url,
                        'type': comic_type,
                        'is_colored': is_colored,
                        'is_hot': is_hot,
                        'latest_chapter': chapter,
                        'chapter_url': chapter_url,
                        'update_time': update_time
                    }

                    comic_list.append(comic_data)
                except Exception as e:
                    logger.error(f"Error parsing comic item: {e}")

            pagination = soup.find('div', class_='pagination')
            total_pages = 1
            if pagination:
                page_links = pagination.find_all('a', class_='page-numbers')
                page_numbers = []
                for link in page_links:
                    text = link.text.strip()
                    if text.isdigit():
                        page_numbers.append(int(text))
                if page_numbers:
                    total_pages = max(page_numbers)

            logger.info(f"Found {len(comic_list)} latest comics on page {page}")
            return {
                'comic_list': comic_list,
                'current_page': page,
                'total_pages': total_pages
            }

        except Exception as e:
            logger.error(f"Error parsing comic list: {e}")
            return {
                'comic_list': [],
                'current_page': page,
                'total_pages': 1
            }

    def get_popular_comics(self):
        """Extract popular comics from the sidebar"""
        logger.info("Fetching popular comics...")
        html = self.get_page(f"{self.base_url}/komik-terbaru/")
        if not html:
            return []

        soup = BeautifulSoup(html, 'html.parser')
        popular_comics = []

        try:
            popular_section = soup.find('div', class_='serieslist pop')
            if not popular_section:
                logger.warning("Popular comics section not found")
                return []

            comic_items = popular_section.find_all('li')

            for item in comic_items:
                try:
                    link_element = item.find('a', class_='series')
                    if not link_element:
                        continue

                    title = link_element.get('title', '').replace('Komik ', '')
                    url = link_element.get('href', '')

                    img_element = item.find('img', itemprop='image')
                    image_url = img_element.get('src', '') if img_element else ''

                    author_element = item.find('span', class_='author')
                    author = author_element.text.strip() if author_element else 'Unknown'

                    rating_element = item.find('span', class_='loveviews')
                    rating = rating_element.text.replace('♥', '').strip() if rating_element else 'N/A'

                    rank_element = item.find('div', class_=re.compile(r'ctr'))
                    rank = rank_element.text.strip() if rank_element else 'N/A'

                    comic_data = {
                        'title': title,
                        'url': url,
                        'image_url': image_url,
                        'author': author,
                        'rating': rating,
                        'rank': rank
                    }

                    popular_comics.append(comic_data)
                except Exception as e:
                    logger.error(f"Error parsing popular comic item: {e}")

            logger.info(f"Found {len(popular_comics)} popular comics")
            return popular_comics

        except Exception as e:
            logger.error(f"Error parsing popular comics: {e}")
            return []

    def get_latest_collections(self):
        """Extract latest comic collections from the sidebar"""
        logger.info("Fetching latest comic collections...")
        html = self.get_page(f"{self.base_url}/")  # Try homepage instead of komik-terbaru
        if not html:
            return []

        soup = BeautifulSoup(html, 'html.parser')
        latest_collections = []

        try:
            # Strategy 1: Try finding section with 'Koleksi Terbaru' or similar
            collection_section = soup.find(lambda tag: tag.name in ['h3', 'h4', 'h2'] and 'Koleksi Terbaru' in tag.text)
            if not collection_section:
                # Strategy 2: Look for alternative section (e.g., widget or sidebar)
                collection_section = soup.find('div', class_='widget')
                if not collection_section:
                    logger.warning("Latest collections section not found")
                    headers = soup.find_all(['h2', 'h3', 'h4'])
                    logger.info(f"Found headers: {[h.text.strip() for h in headers]}")
                    return []

            # Find the nearest series list
            series_list = collection_section.find_next('div', class_='serieslist')
            if not series_list:
                logger.warning("Series list not found after collection section")
                return []

            comic_items = series_list.find_all('li')

            for item in comic_items:
                try:
                    link_element = item.find('a', class_='series')
                    if not link_element:
                        continue

                    title = link_element.get('title', '').replace('Manga ', '').replace('Komik ', '')
                    url = link_element.get('href', '')

                    img_element = item.find('img', itemprop='image')
                    image_url = img_element.get('src', '') if img_element else ''

                    genre_element = item.find('span', class_='genre')
                    genres = genre_element.text.strip().split(', ') if genre_element else []

                    rating_element = item.find('span', class_='loveviews')
                    rating = rating_element.text.replace('♥', '').strip() if rating_element else 'N/A'

                    comic_data = {
                        'title': title,
                        'url': url,
                        'image_url': image_url,
                        'genres': genres,
                        'rating': rating
                    }

                    latest_collections.append(comic_data)
                except Exception as e:
                    logger.error(f"Error parsing latest collection item: {e}")

            logger.info(f"Found {len(latest_collections)} latest collections")
            return latest_collections

        except Exception as e:
            logger.error(f"Error parsing latest collections: {e}")
            return []

    def parse_relative_time(self, time_str):
        """Parse relative time strings into a formatted date (e.g., '4 menit yang lalu' to 'April 20, 2025')"""
        try:
            time_str = time_str.lower()
            current_time = datetime.now()

            if 'menit' in time_str:
                minutes = int(time_str.split()[0])
                return (current_time - timedelta(minutes=minutes)).strftime('%B %d, %Y')
            elif 'jam' in time_str:
                hours = int(time_str.split()[0])
                return (current_time - timedelta(hours=hours)).strftime('%B %d, %Y')
            elif 'hari' in time_str:
                days = int(time_str.split()[0])
                return (current_time - timedelta(days=days)).strftime('%B %d, %Y')
            elif 'minggu' in time_str:
                weeks = int(time_str.split()[0])
                return (current_time - timedelta(weeks=weeks)).strftime('%B %d, %Y')
            elif 'bulan' in time_str:
                months = int(time_str.split()[0])
                # Approximate months as 30 days
                return (current_time - timedelta(days=months*30)).strftime('%B %d, %Y')
            elif 'tahun' in time_str:
                years = int(time_str.split()[0])
                return (current_time - timedelta(days=years*365)).strftime('%B %d, %Y')
            else:
                return time_str  # Return original string if format is unknown
        except (ValueError, IndexError) as e:
            logger.warning(f"Failed to parse relative time '{time_str}': {e}")
            return time_str

    def get_comic_details(self, url):
        """Extract detailed information about a comic from its detail page"""
        logger.info(f"Fetching comic details from {url}...")
        html = self.get_page(url)
        if not html:
            return {}

        soup = BeautifulSoup(html, 'html.parser')

        try:
            # Extract title
            title_element = soup.find('h1', class_='entry-title')
            title = title_element.text.replace('Komik', '').strip() if title_element else 'Unknown Title'

            # Extract image
            img_element = soup.find('div', class_='thumb').find('img') if soup.find('div', class_='thumb') else None
            image_url = img_element.get('src', '') if img_element else ''

            # Extract rating
            rating_element = soup.find('i', itemprop='ratingValue')
            rating = rating_element.text.strip() if rating_element else 'N/A'

            # Extract information from <div class="spe">
            spe_section = soup.find('div', class_='spe')
            alternative_titles = []
            status = 'Unknown'
            author = 'Unknown'
            illustrator = 'Unknown'
            demographic = 'Unknown'
            comic_type = 'Unknown'
            themes = []

            if spe_section:
                spans = spe_section.find_all('span')
                for span in spans:
                    label_tag = span.find('b')
                    if not label_tag:
                        continue
                    label = label_tag.text.strip().rstrip(':').lower()
                    value = span.get_text(strip=True).replace(label_tag.text, '').strip()

                    if label == 'judul alternatif':
                        alternative_titles = [title.strip() for title in value.split(',') if title.strip()]
                    elif label == 'status':
                        status = value
                    elif label == 'pengarang':
                        author = value
                    elif label == 'ilustrator':
                        illustrator = value
                    elif label == 'grafis':
                        demographic_link = span.find('a')
                        demographic = demographic_link.text.strip() if demographic_link else value
                    elif label == 'tema':
                        themes = [a.text.strip() for a in span.find_all('a')]
                    elif label == 'jenis komik':
                        type_link = span.find('a')
                        comic_type = type_link.text.strip() if type_link else value

            # Extract genres
            genre_elements = soup.find('div', class_='genre-info').find_all('a') if soup.find('div', class_='genre-info') else []
            genres = [genre.text.strip() for genre in genre_elements]

            # Extract synopsis
            synopsis_element = soup.find('div', class_='entry-content', itemprop='description')
            synopsis = synopsis_element.text.strip() if synopsis_element else 'No synopsis available'

            # Extract chapters
            chapters = []
            chapter_list = soup.find('div', class_='listeps').find('ul') if soup.find('div', class_='listeps') else None
            last_updated = 'Unknown'
            if chapter_list:
                chapter_items = chapter_list.find_all('li')
                for item in chapter_items:
                    chapter_link = item.find('a')
                    chapter_title = chapter_link.text.strip() if chapter_link else 'Unknown Chapter'
                    chapter_url = chapter_link.get('href', '') if chapter_link else ''
                    update_time = item.find('span', class_='dt').text.strip() if item.find('span', class_='dt') else 'N/A'
                    chapters.append({
                        'title': chapter_title,
                        'url': chapter_url,
                        'update_time': update_time
                    })
                # Extract last_updated from the most recent chapter
                if chapter_items:
                    last_updated = chapter_items[0].find('span', class_='dt').text.strip() if chapter_items[0].find('span', class_='dt') else 'Unknown'
                    last_updated = self.parse_relative_time(last_updated)

            # Extract related comics
            related_comics = []
            related_section = soup.find('div', id='mirip')
            if related_section:
                related_items = related_section.find_all('li')
                for item in related_items:
                    link_element = item.find('a', class_='series')
                    if link_element:
                        related_title = link_element.get('title', '').replace('Komik', '').strip()
                        related_url = link_element.get('href', '')
                        related_img = item.find('img').get('src', '') if item.find('img') else ''
                        related_comics.append({
                            'title': related_title,
                            'url': related_url,
                            'image_url': related_img
                        })

            # Construct comic details
            comic_details = {
                'title': title,
                'image_url': image_url,
                'rating': rating,
                'alternative_titles': alternative_titles,
                'status': status,
                'author': author,
                'illustrator': illustrator,
                'demographic': demographic,
                'type': comic_type,
                'genres': genres,
                'themes': themes,
                'synopsis': synopsis,
                'chapters': chapters,
                'related_comics': related_comics,
                'last_updated': last_updated
            }

            logger.info(f"Successfully extracted details for {title}")
            return comic_details

        except Exception as e:
            logger.error(f"Error extracting comic details: {e}")
            return {}

    def get_chapter_images(self, url):
        """Extract images and metadata from a comic chapter page"""
        logger.info(f"Attempting to fetch chapter images from {url}")
        html = self.get_page(url)
        if not html:
            logger.error(f"Failed to retrieve HTML content for {url}")
            return {}

        soup = BeautifulSoup(html, 'html.parser')

        try:
            # Log the HTML content for debugging (first 500 characters)
            logger.debug(f"HTML content (first 500 chars): {html[:500]}")

            # Extract title
            title_element = soup.find('h1', class_='entry-title')
            title = title_element.text.replace('Komik', '').strip() if title_element else 'Unknown Chapter'
            logger.info(f"Extracted chapter title: {title}")
            
            # Extract chapter number from title or URL
            chapter_number = 'Unknown'
            # Try to extract from title first (e.g., "Chapter 123", "Ch. 123", "123")
            chapter_match = re.search(r'(?:chapter|ch\.?)\s*(\d+)', title, re.IGNORECASE)
            if chapter_match:
                chapter_number = chapter_match.group(1)
            else:
                # Try to extract from URL (e.g., "/chapter-123/")
                url_match = re.search(r'chapter[\-_](\d+)', url, re.IGNORECASE)
                if url_match:
                    chapter_number = url_match.group(1)
                else:
                    # Try to extract any number from title as fallback
                    number_match = re.search(r'(\d+)', title)
                    if number_match:
                        chapter_number = number_match.group(1)
            logger.info(f"Extracted chapter number: {chapter_number}")

            # Extract description
            desc_element = soup.find('div', class_='chapter-desc')
            description = desc_element.text.strip() if desc_element else 'No description available'
            logger.info(f"Extracted description: {description[:100]}...")

            # Extract images
            image_container = soup.find('div', class_='chapter-image')
            images = []
            if image_container:
                img_elements = image_container.find_all('img')
                for img in img_elements:
                    img_url = img.get('src', '')
                    alt_text = img.get('alt', title)
                    if img_url:
                        images.append({
                            'url': img_url,
                            'alt': alt_text
                        })
                logger.info(f"Found {len(images)} images in chapter")
            else:
                logger.warning("No image container found in chapter page")

            # Extract navigation links
            navigation = {}
            navig_sections = soup.find_all('div', class_='navig')
            for navig in navig_sections:
                nextprev = navig.find('div', class_='nextprev')
                if nextprev:
                    # Chapter list link
                    chapter_list_link = nextprev.find('a', href=re.compile(r'/komik/'))
                    if chapter_list_link:
                        navigation['chapter_list'] = chapter_list_link.get('href', '')
                        logger.info(f"Found chapter list link: {navigation['chapter_list']}")

                    # Next chapter link
                    next_chapter_link = nextprev.find('a', rel='next')
                    if next_chapter_link:
                        navigation['next_chapter'] = next_chapter_link.get('href', '')
                        logger.info(f"Found next chapter link: {navigation['next_chapter']}")

                    # Previous chapter link (if available)
                    prev_chapter_link = nextprev.find('a', rel='prev')
                    if prev_chapter_link:
                        navigation['prev_chapter'] = prev_chapter_link.get('href', '')
                        logger.info(f"Found previous chapter link: {navigation['prev_chapter']}")

            # Extract related chapters from sidebar
            related_chapters = []
            chapter_list = soup.find('div', class_='listeps')
            if chapter_list:
                chapter_items = chapter_list.find_all('li')
                for item in chapter_items:
                    chapter_link = item.find('a')
                    if chapter_link:
                        chapter_title = chapter_link.text.strip()
                        chapter_url = chapter_link.get('href', '')
                        related_chapters.append({
                            'title': chapter_title,
                            'url': chapter_url
                        })
                logger.info(f"Found {len(related_chapters)} related chapters")

            chapter_data = {
                'title': title,
                'description': description,
                'images': images,
                'navigation': navigation,
                'related_chapters': related_chapters
            }

            logger.info(f"Successfully extracted {len(images)} images for {title}")
            return chapter_data

        except Exception as e:
            logger.error(f"Error extracting chapter images: {e}")
            return {}

    def search_comics(self, query):
        """Search for comics by title"""
        logger.info(f"Searching for comics: {query}")
        encoded_query = urllib.parse.quote(query)
        search_url = f"{self.base_url}/?s={encoded_query}"

        html = self.get_page(search_url)
        if not html:
            return []

        soup = BeautifulSoup(html, 'html.parser')
        search_results = []

        try:
            result_items = soup.select('.animepost')
            if not result_items:
                logger.info("No comic results found")
                return []

            for item in result_items:
                try:
                    link_element = item.find('a', itemprop='url')
                    if not link_element:
                        continue

                    title = link_element.get('title', '').replace('Komik ', '')
                    url = link_element.get('href', '')

                    img_element = item.find('img', itemprop='image')
                    image_url = img_element.get('src', '') if img_element else ''

                    type_element = item.find('span', class_=re.compile(r'typeflag'))
                    comic_type = type_element.get('class', [''])[-1] if type_element else 'Unknown'

                    rating_element = item.find('i')
                    rating = rating_element.text.strip() if rating_element else 'N/A'

                    comic_info = {
                        'title': title,
                        'url': url,
                        'image_url': image_url,
                        'type': comic_type,
                        'rating': rating
                    }

                    search_results.append(comic_info)
                except Exception as e:
                    logger.error(f"Error parsing search result item: {e}")

            logger.info(f"Found {len(search_results)} results for '{query}'")
            if search_results:
                logger.info(f"First result: {json.dumps(search_results[0], indent=2)}")

            return search_results

        except Exception as e:
            logger.error(f"Error searching for comics: {e}")
            logger.error(f"Search URL: {search_url}")
            logger.error(f"HTML snippet: {html[:500]}..." if html else "No HTML content")
            return []

# Initialize scrapers
winbu_scraper = WinbuScraper()
komikindo_scraper = KomikindoScraper()

@app.route('/')
def index():
    return "I am alive!"

@app.route('/top-anime', methods=['GET'])
def top_anime():
    try:
        result = winbu_scraper.get_top_anime()
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in top-anime endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/latest-anime', methods=['GET'])
def latest_anime():
    try:
        page = request.args.get('page', 1, type=int)
        result = winbu_scraper.get_latest_anime(page)
        if not isinstance(result, dict) or 'anime_list' not in result:
            logger.error("Invalid result structure from get_latest_anime")
            result = {
                'anime_list': [],
                'current_page': page,
                'total_pages': 1
            }
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in latest-anime endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e),
            "data": {
                'anime_list': [],
                'current_page': request.args.get('page', 1, type=int),
                'total_pages': 1
            }
        }), 500

@app.route('/anime-details', methods=['GET'])
def anime_details():
    try:
        url = request.args.get('url')
        if not url:
            return jsonify({
                "success": False,
                "error": "Missing 'url' parameter"
            }), 400

        result = winbu_scraper.get_anime_details(url)
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in anime-details endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/episode-streams', methods=['GET'])
def episode_streams():
    try:
        url = request.args.get('url')
        if not url:
            return jsonify({
                "success": False,
                "error": "Missing 'url' parameter"
            }), 400

        result = winbu_scraper.get_episode_streams(url)
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in episode-streams endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/search', methods=['GET'])
def search():
    try:
        query = request.args.get('query')
        if not query:
            return jsonify({
                "success": False,
                "error": "Missing 'query' parameter"
            }), 400

        logger.info(f"Search request received for query: '{query}'")
        result = winbu_scraper.search_anime(query)
        logger.info(f"Returning {len(result)} search results")
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in search endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/release-schedule', methods=['GET'])
def release_schedule():
    try:
        day = request.args.get('day')
        result = winbu_scraper.get_release_schedule(day)
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in release-schedule endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/latest-comics', methods=['GET'])
def latest_comics():
    try:
        page = request.args.get('page', 1, type=int)
        result = komikindo_scraper.get_latest_comics(page)
        if not isinstance(result, dict) or 'comic_list' not in result:
            logger.error("Invalid result structure from get_latest_comics")
            result = {
                'comic_list': [],
                'current_page': page,
                'total_pages': 1
            }
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in latest-comics endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e),
            "data": {
                'comic_list': [],
                'current_page': request.args.get('page', 1, type=int),
                'total_pages': 1
            }
        }), 500

@app.route('/popular-comics', methods=['GET'])
def popular_comics():
    try:
        result = komikindo_scraper.get_popular_comics()
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in popular-comics endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/latest-collections', methods=['GET'])
def latest_collections():
    try:
        result = komikindo_scraper.get_latest_collections()
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in latest-collections endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/comic-details', methods=['GET'])
def comic_details():
    try:
        url = request.args.get('url')
        if not url:
            return jsonify({
                "success": False,
                "error": "Missing 'url' parameter"
            }), 400

        result = komikindo_scraper.get_comic_details(url)
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in comic-details endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/chapter-images', methods=['GET'])
def chapter_images():
    try:
        chapter_input = request.args.get('url')
        if not chapter_input:
            logger.error("Missing 'url' parameter in chapter-images request")
            return jsonify({
                "success": False,
                "error": "Missing 'url' parameter"
            }), 400

        # Determine if the input is a full URL or just a slug
        if chapter_input.startswith('https://'):
            # It's a full URL, parse and validate it
            parsed_url = urllib.parse.urlparse(chapter_input)
            if not parsed_url.scheme or not parsed_url.netloc:
                logger.error(f"Invalid URL provided: {chapter_input}")
                return jsonify({
                    "success": False,
                    "error": "Invalid URL provided"
                }), 400
            chapter_url = chapter_input.rstrip('/')
        else:
            # It's a slug, reconstruct the full URL
            chapter_url = f"https://komikindo.ch/{chapter_input.strip('/')}/"

        logger.debug(f"Constructed chapter_url: {chapter_url}")

        # Validate the constructed URL
        parsed_url = urllib.parse.urlparse(chapter_url)
        if not parsed_url.scheme or not parsed_url.netloc:
            logger.error(f"Constructed invalid URL: {chapter_url}")
            return jsonify({
                "success": False,
                "error": "Invalid constructed URL"
            }), 500

        logger.info(f"Fetching chapter images from: {chapter_url}")
        result = komikindo_scraper.get_chapter_images(chapter_url)
        
        # Check if the result is empty or indicates a failure
        if not result or not isinstance(result, dict) or not result.get('images'):
            logger.warning(f"No images found for chapter URL: {chapter_url}")
            return jsonify({
                "success": False,
                "error": "Failed to fetch chapter images",
                "data": {}
            }), 500

        logger.info(f"Successfully fetched chapter images for URL: {chapter_url}")
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in chapter-images endpoint: {e}")
        return jsonify({
            "success": False,
            "error": f"Server error: {str(e)}",
            "data": {}
        }), 500

@app.route('/search-comics', methods=['GET'])
def search_comics():
    try:
        query = request.args.get('query')
        if not query:
            return jsonify({
                "success": False,
                "error": "Missing 'query' parameter"
            }), 400

        logger.info(f"Search comics request received for query: '{query}'")
        result = komikindo_scraper.search_comics(query)
        logger.info(f"Returning {len(result)} search results")
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in search-comics endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/genres', methods=['GET'])
def genres():
    try:
        result = winbu_scraper.get_genres()
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in genres endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/genre-content', methods=['GET'])
def genre_content():
    try:
        genre_url = request.args.get('url')
        page = request.args.get('page', 1, type=int)
        
        if not genre_url:
            return jsonify({
                "success": False,
                "error": "Missing 'url' parameter"
            }), 400
        
        result = winbu_scraper.get_genre_content(genre_url, page)
        return jsonify({
            "success": True,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in genre-content endpoint: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/app_version', methods=['GET'])
def get_app_version():
    """Get the latest app version information"""
    try:
        global app_version_data
        # Reload the latest version data
        app_version_data = load_app_version()
        return jsonify(app_version_data)
    except Exception as e:
        logger.error(f"Error in app_version endpoint: {e}")
        return jsonify({
            "error": "Failed to get app version",
            "message": str(e)
        }), 500

@app.route('/api/update', methods=['POST'])
def update_app_version():
    """Update app version information"""
    try:
        global app_version_data
        
        # Check if request is JSON
        if not request.is_json:
            return jsonify({
                "error": "Invalid request format",
                "message": "Request must be JSON"
            }), 400
        
        data = request.get_json()
        
        # Validate required fields
        if not all(key in data for key in ['version', 'download_url', 'changelog']):
            return jsonify({
                "error": "Missing required fields",
                "message": "version, download_url, and changelog are required"
            }), 400
        
        # Update version data
        app_version_data = {
            "version": data['version'],
            "download_url": data['download_url'],
            "changelog": data['changelog']
        }
        
        # Save to file
        if save_app_version(app_version_data):
            logger.info(f"App version updated to {data['version']}")
            return jsonify({
                "success": True,
                "message": "App version updated successfully",
                "data": app_version_data
            })
        else:
            return jsonify({
                "error": "Failed to save version data",
                "message": "Could not write to version file"
            }), 500
            
    except Exception as e:
        logger.error(f"Error in update endpoint: {e}")
        return jsonify({
            "error": "Failed to update app version",
            "message": str(e)
        }), 500

@app.route('/extract', methods=['GET', 'POST'])
def extract_stream():
    """Extract stream URL from embed URL or comic data."""
    if request.method == 'GET':
        return '''
        <!DOCTYPE html>
        <html>
        <head>
            <title>Winbu.tv & Komikindo Scraper</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .container { max-width: 600px; margin: 0 auto; }
                .form-group { margin-bottom: 20px; }
                label { display: block; margin-bottom: 5px; }
                input[type="text"] { width: 100%; padding: 8px; margin-bottom: 10px; }
                button { background-color: #4CAF50; color: white; padding: 10px 15px; border: none; cursor: pointer; }
                button:hover { background-color: #45a049; }
                .result { margin-top: 20px; padding: 15px; border: 1px solid #ddd; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Winbu.tv & Komikindo Scraper</h1>
                <form method="POST" action="/extract">
                    <div class="form-group">
                        <label for="embed_url">Enter Anime or Comic URL or Search Query:</label>
                        <input type="text" id="embed_url" name="embed_url" required placeholder="e.g., https://winbu.tv/anime/one-piece/ or https://komikindo.ch/komik/magic-emperor/ or https://komikindo.ch/the-crazy-genius-composer-returns-chapter-1/ or alya">
                    </div>
                    <button type="submit">Extract Data</button>
                </form>
            </div>
        </body>
        </html>
        '''

    try:
        if request.is_json:
            data = request.get_json()
        else:
            data = request.form

        if not data or 'embed_url' not in data:
            return jsonify({"error": "Missing embed_url in request"}), 400

        embed_url = data['embed_url']
        result_type = None
        result = None

        if 'winbu.tv' in embed_url:
            if '/anime/' in embed_url and not '/episode' in embed_url:
                result = winbu_scraper.get_anime_details(embed_url)
                result_type = "anime_details"
            elif '/episode' in embed_url:
                result = winbu_scraper.get_episode_streams(embed_url)
                result_type = "episode_streams"
            else:
                query = embed_url.split('/')[-1] if '/' in embed_url else embed_url
                result = winbu_scraper.search_anime(query)
                result_type = "search_results"
        elif 'komikindo.ch' in embed_url: 
            if '/komik/' in embed_url:
                result = komikindo_scraper.get_comic_details(embed_url)
                result_type = "comic_details"
            elif 'chapter-' in embed_url:
                result = komikindo_scraper.get_chapter_images(embed_url)
                result_type = "chapter_images"
            else:
                query = embed_url.split('/')[-1] if '/' in embed_url else embed_url
                result = komikindo_scraper.search_comics(query)
                result_type = "comic_search_results"
        else:
            # Treat as a search query for comics
            result = komikindo_scraper.search_comics(embed_url)
            result_type = "comic_search_results"

        if not request.is_json:
            return f'''
            <!DOCTYPE html>
            <html>
            <head>
                <title>Extraction Result</title>
                <style>
                    body {{ font-family: Arial, sans-serif; margin: 40px; }}
                    .container {{ max-width: 800px; margin: 0 auto; }}
                    .result {{ margin-top: 20px; padding: 15px; border: 1px solid #ddd; }}
                    .back-button {{ margin-top: 20px; }}
                    .back-button a {{ text-decoration: none; color: #666; }}
                    pre {{ background-color: #f5f5f5; padding: 10px; overflow-x: auto; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Extraction Result</h1>
                    <div class="result">
                        <h3>Type: {result_type}</h3>
                        <pre>{json.dumps(result, indent=2)}</pre>
                    </div>
                    <div class="back-button">
                        <a href="/extract">← Back to Extractor</a>
                    </div>
                </div>
            </body>
            </html>
            '''

        return jsonify({
            "success": True,
            "type": result_type,
            "data": result
        })
    except Exception as e:
        logger.error(f"Error in extract endpoint: {e}")
        error_response = {"error": str(e)}
        if not request.is_json:
            return f'''
            <!DOCTYPE html>
            <html>
            <head>
                <title>Error</title>
                <style>
                    body {{ font-family: Arial, sans-serif; margin: 40px; }}
                    .container {{ max-width: 600px; margin: 0 auto; }}
                    .error {{ color: red; padding: 15px; border: 1px solid #ffcdd2; background-color: #ffebee; }}
                    .back-button {{ margin-top: 20px; }}
                    .back-button a {{ text-decoration: none; color: #666; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Error</h1>
                    <div class="error">
                        <p>{str(e)}</p>
                    </div>
                    <div class="back-button"><a href="/extract">← Back to Extractor</a>
                    </div>
                </div>
            </body>
            </html>
            '''
        return jsonify(error_response), 500

@app.errorhandler(404)
def not_found_error(error):
    return jsonify({
        "error": "Not Found",
        "message": "The requested URL was not found on the server."
    }), 404

if __name__ == '__main__':
    keep_alive()  # Start keep-alive server
    app.run(debug=True, host='0.0.0.0', port=5000)