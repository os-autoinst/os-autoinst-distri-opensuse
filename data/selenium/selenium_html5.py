import sys

from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.firefox.options import Options


fail = False
res = {}
audio_codecs = [
        "row-audio.codecs.pcm",
        "row-audio.codecs.mp3",
        "row-audio.codecs.mp4.aac",
        "row-audio.codecs.mp4.ac3",
        "row-audio.codecs.mp4.ec3",
        "row-audio.codecs.ogg.vorbis",
        "row-audio.codecs.ogg.opus"
        ]
img_formats = [
        "row-canvas.jpeg",
        "row-canvas.png",
        "row-canvas.jpegxr",
        "row-canvas.webp"
        ]
video_codecs = [
        "row-video.codecs.mp4.mpeg4",
        "row-video.codecs.mp4.h264",
        "row-video.codecs.mp4.h265",
        "row-video.codecs.ogg.theora",
        "row-video.codecs.webm.vp8",
        "row-video.codecs.webm.vp9",
        ]

def prepare_driver():
    options = Options()
    options.headless = True
    driver = webdriver.Firefox(".", options=options)
    driver.get("https://html5test.opensuse.org/")
    return driver

def check_score(driver):
    global fail
    WebDriverWait(driver, 1000000).until(EC.presence_of_element_located((By.XPATH, '//*[@id="score"]/div/h2/strong')))
    element = driver.find_element_by_xpath('//*[@id="score"]/div/h2/strong')
    print("\n==================\n")
    score = int(element.text)
    if score < 500:
        print("OVERALL SCORE: FAIL [[" + str(score) + " (<500), too low!]]")
        fail = True
    else:
        print("OVERALL SCORE: OK " + str(score) + " (>500), all good!")

def check_video(driver):
    global res, fail
    res["video"] = []
    element = driver.find_element_by_xpath('//*[@id="head-video"]/th/div/div/span')
    video_score = element.text
    if int(video_score.split("/")[0]) < 28:
        print("VIDEO SCORE: FAIL [[Supported video codecs are <28, too low!]]")
        fail = True
    else:
        print("VIDEO SCORE: OK (Supported video codecs are " + str(video_score) + " (>28), all good!)")
    for codec in video_codecs:
        element = driver.find_element_by_xpath('//*[@id="' + codec + '"]/td/div')
        if "No" in element.text:
            res["video"].append(codec)
    if res["video"]:
        print("Unsupported video codecs:\n----------\n")
        for codec in res["video"]:
            print(codec)
    else:
        print("All video codecs are supported!")

def check_audio(driver):
    global res, fail
    res["audio"] = []
    element = driver.find_element_by_xpath('//*[@id="head-audio"]/th/div/div/span')
    audio_score = element.text
    if int(audio_score.split("/")[0]) < 27:
        print("AUDIO SCORE: FAIL [[Supported audio codecs are " + audio_score.split("/")[0] + " (<27), too low!]]")
        fail = True
    else:
        print("AUDIO SCORE: OK (Supported audio codecs are " + str(audio_score) + " (>=27), all good!)")
    for codec in audio_codecs:
        element = driver.find_element_by_xpath('//*[@id="' + codec + '"]/td/div')
        if "No" in element.text:
            res["audio"].append(codec)
    if res["audio"]:
        print("Unsupported audio codecs:\n----------\n")
        for codec in res["audio"]:
            print(codec)
    else:
        print("All audio codecs are supported!")

# PREPARE DRIVER
try:
    driver = prepare_driver()
except Exception as e:
    print("DRIVER PREPARATION: FAIL [[" + str(e) + "]]")
    sys.exit(1)

# OVERALL SCORE CHECK
try:
    check_score(driver)
except Exception as e:
    print("OVERALL SCORE: FAIL [[" + str(e) + "]]")
    fail = True

# VIDEO SCORE + CODEC CHECK
try:
    check_video(driver)
except Exception as e:
    print("VIDEO SCORE: FAIL [[" + str(e) + "]]")
    fail = True

# AUDIO SCORE + CODEC CHECK
try:
    check_audio(driver)
except Exception as e:
    print("AUDIO SCORE: FAIL [[" + str(e) + "]]")
    fail = True

if fail:
    print("TEST FAILED")
else:
    print("TESTS OK")
