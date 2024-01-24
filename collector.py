"""Code written for Academic project at UCL 
based on pytrends, https://ggiesa.wordpress.com/2018/05/15/scraping-google-trends-with-selenium-and-python/, 
Bordeur et al (2021) and https://github.com/jack-madison/Google-Trends"""


from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By

from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from urllib.parse import quote

import time
import os
import pandas as pd
from datetime import date, timedelta
from calendar import monthrange
from copy import deepcopy


from njord import Client
from utils.configs import nord_vpn_config

base_url = 'https://trends.google.com/trends/explore?'
webdriver_path = '/opt/homebrew/bin/chromedriver'

def check_dir(dirname: str) -> str: 
    """Checks if directory exists, if not creates directory
        Args:
        dirname (str) : name of directory/path to check"""
    if not os.path.exists(dirname):
        os.mkdir(dirname)
    return dirname


def convert_dates_to_timeframe(start: date, stop: date) -> str:
    """Given two dates, returns a stringified version of the interval between
    the two dates which is used to retrieve data for a specific time frame
    from Google Trends.
    """
    return f"{start.strftime('%Y-%m-%d')} {stop.strftime('%Y-%m-%d')}"



def gen_timeframes_from_event(event_date):
    event_date =pd.to_datetime(event_date)
    start,end = event_date - timedelta(int(75)), event_date +  timedelta(int(30))
    if start.day_of_week != 6:
        start = start - timedelta(start.day_of_week + int(1))
    if end.day_of_week != 6:
        end = end - timedelta(end.day_of_week + int(1))
    start1 = start-timedelta(days=int(365))
    if start1.day_of_week !=6:
        start1 = start1 - timedelta(int(6) - start1.day_of_week)
    num_weeks = (end-start).days/7
    end1 = start1 + timedelta(days=int(num_weeks*7))
    tf_week = convert_dates_to_timeframe(start1,end)
    tf_day_20 = convert_dates_to_timeframe(start1,end1)
    tf_day_21 = convert_dates_to_timeframe(start,end)
    return tf_week, tf_day_20, tf_day_21



error_not_enough_data = """warning\nHmm, your search doesn't have enough data to show here.\nPlease make sure everything is spelled correctly, or try a more general term."""

class ProxyItem:
    def __init__(self):
        self.gen_client()

    def gen_client(self):
        if nord_vpn_config['username'] and nord_vpn_config['password']:
            username = nord_vpn_config['username']
            password = nord_vpn_config['password']
        else:
            import getpass
            username = getpass.getpass('Username for NORDVPN API')
            password = getpass.getpass('Password for NORDVPN API')
        self.client = Client(username,password)
        self.test_client()
    
    def test_client(self):
        try:
            self.client.connect()
        except Exception as e:
            print(f'Error with connection : {e}')
            return
        
    def regen(self):
        self.client.disconnect()
        self.test_client()


class ChromeSession:
    def __init__(self,base_dir,sleep_time=int(3),proxy=None):
        self.base_dir = base_dir
        self.sleep_time = sleep_time
        if proxy:
            self.client = proxy
        self.service = Service(executable_path=webdriver_path)
    

    def gen_options(self,download=True,headless=False):
        chrome_options = Options()
        if download:
            download_prefs = {'download.default_directory' : os.path.abspath(self.base_dir),
                        'download.prompt_for_download' : False,
                        'profile.default_content_settings.popups' : False,
                        'download.directory_upgrade': True,
                        'safebrowsing.enabled': True}
            chrome_options.add_experimental_option('prefs', download_prefs)
            chrome_options.add_argument('--window-size=480x270')
            self.caps = deepcopy(chrome_options.to_capabilities())
        if headless:
            chrome_options.add_argument('--headless=new')
        else:
            chrome_options.add_argument('--window-size=480x270')
        return chrome_options

    def init_browser(self,download=True,headless=False):
        chrome_options = self.gen_options(download,headless)
        self.browser = webdriver.Chrome(service=self.service,options=chrome_options)

    def init_google_session(self,url=None):
        if not url:
            url = base_url
        else:
            self.curr_url = url
        self.browser.get(url)
        self.browser.refresh()
        while self.has_cookie_banner():
            self.has_cookie_banner()

    def update_options(self,new_dir):
        new_caps = self.caps.copy()
        new_caps['goog:chromeOptions']['prefs']['download.default_directory'] = new_dir
        return new_caps
    
    def change_download_dir(self,new_dir):
        new_caps = self.update_options(new_dir)
        self.browser.close()
        self.browser.start_session(new_caps)
    
    def continue_session(self,url):
        self.curr_url = url
        self.browser.get(url)
        self.browser.refresh()

    def change_session(self, new_dir,url):
        self.change_download_dir(os.path.abspath(new_dir))
        self.curr_url = url
        self.continue_session(url)
        while self.has_cookie_banner():
            self.has_cookie_banner()

    def get_element(self,selector,click=True):
        attempts,element = 0, False
        while not self.is_valid_page():
            attempts = self.handle_exception(attempts)
        try:
            element = WebDriverWait(self.browser, self.sleep_time).until(EC.element_to_be_clickable((By.CSS_SELECTOR, selector)))
            if click:
                element.click()
                return True
            else:
                return element
        except Exception as e:
            print(f'Error find selector {selector}')
            attempts = self.handle_exception(attempts)
        return False

    def is_valid_page(self):
        errorFound = True
        try:
            errorFound = WebDriverWait(self.browser, self.sleep_time).until(EC.presence_of_element_located((By.CSS_SELECTOR, '.widget-error')))
            if errorFound.text == error_not_enough_data:
                return True
            else:
                return False
        except:
            return errorFound
    
    def has_cookie_banner(self):
        cookie_banner = True
        try:
            cookie_banner = WebDriverWait(self.browser, self.sleep_time).until(EC.element_to_be_clickable((By.CSS_SELECTOR, ".cookieBarButton.cookieBarConsentButton")))
            if cookie_banner:
                cookie_banner.click()
                return False
        except:
            return cookie_banner

    def download_trend_data(self):
        element = self.get_element('.widget-actions-item.export')
        time.sleep(float(1.5))
        return element
            
    def download_geo_data(self,low_regions=False):
        if low_regions:
            checkbox_element = self.get_element('md-checkbox[aria-label="Include low search volume regions"]')
            time.sleep(self.sleep_time)
            button_geo = self.get_element('.fe-geo-chart-generated .widget-actions-item.export')
        else:
            button_geo  = self.get_element('.fe-geo-chart-generated .widget-actions-item.export')
        return button_geo

    def regen(self):
        current_url = self.curr_url
        self.browser.quit()
        self.client.regen()
        self.init_browser()
        self.base_dir = self.caps['goog:chromeOptions']['prefs']['download.default_directory']
        self.init_google_session(current_url)

    def handle_exception(self,attempts):
        self.browser.refresh()
        time.sleep(self.sleep_time)
        attempts+=1
        if attempts == 10:
            self.regen()
        return attempts


class DataCollectorSimple:
    def __init__(self, kw_list, geo_regions, event_date,proxy=None):
        self.proxy = proxy
        self.kw_list = kw_list
        self.kws = ','.join(self.kw_list)
        self.regions = geo_regions
        #self.gen_download_dirs(kw_list)
        self.sess = None
        self.tfs = gen_timeframes_from_event(event_date)

    def gen_download_dirs(self,kw_list):
        """Creates directory to save the csv files of Google Trends data"""
        self.download_paths = {}
        for kw in kw_list:
            kw = kw.replace(',','_').replace(' ','_')
            self.download_paths[kw] = check_dir(os.path.join('data',kw))

    def gen_url(self, time_range: str, geo:str, kws: str) -> str:
        """Creates the url to request csv file in Google Trends
            Args: time_range(str) : time range of data to collect in format YYYY-MM-DD YYYY-MM-DD"""
        if geo == '':
            url_ = f'{base_url}date={quote(time_range)}&q={quote(kws)}&hl=en-GB'
        else:
            url_ = f'{base_url}date={quote(time_range)}&geo={geo}&q={quote(kws)}&hl=en-GB'
        return url_
    
    def download_data(self, url):
        self.sess.continue_session(url)
        res = 0
        res = self.sess.download_trend_data()


    def get_weekly(self, region, kw,geo_dir):
        url = self.gen_url(self.tfs[0],region,kw)
        self.sess.continue_session(url)
        res = self.sess.download_trend_data()
        if res:
            time.sleep(float(1.5))
            new_name = os.path.join(geo_dir,f"weekly_timeline.csv")
            os.rename(os.path.join(self.download_path,'multiTimeline.csv'),new_name)
        else:
            print("NO")
            return

    def get_daily(self, tf, region, kw,geo_dir):
        url = self.gen_url(tf,region,kw)
        self.sess.continue_session(url)
        res = self.sess.download_trend_data()
        range_id = '_'.join([x[2:4] for x in tf.split(' ')])
        if res:
            time.sleep(float(1.5))
            new_name = os.path.join(geo_dir,f"daily_{range_id}_timeline.csv")
            os.rename(os.path.join(self.download_path,'multiTimeline.csv'),new_name)
        else:
            print("NO")
            return
    
    def open_session(self,url,new_dir=False):
        if new_dir:
            self.sess.change_download_dir(self.download_path)
            self.sess.init_google_session(url)
        if not self.sess:
            self.sess = ChromeSession(self.download_path, sleep_time=int(3),proxy=self.proxy)
            self.sess.init_browser()
            self.sess.init_google_session(url)
    

    def loop_regions(self, kw,new_dir=False):
        self.download_path = check_dir(os.path.join('data',kw.replace(' ','_')))
        fake_url = self.gen_url(self.tfs[0],'',kw)
        self.open_session(fake_url,new_dir)
        for region in self.regions:
            if region == '':
                geo_dir = check_dir(os.path.join(self.download_path, 'world'))
            else:
                geo_dir = check_dir(os.path.join(self.download_path, region))
            self.get_weekly(region, kw, geo_dir)
            self.get_daily(self.tfs[1],region, kw, geo_dir)
            self.get_daily(self.tfs[2],region, kw, geo_dir)
        self.proxy.client.disconnect()
    
