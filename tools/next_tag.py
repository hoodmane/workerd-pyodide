#!/usr/bin/python3
import json
import urllib.request
import datetime

GITHUB_ACCESS_TOKEN = ""

def github_urlopen(url):
    """
    A wrapper around urllib.request.urlopen() which parses GitHub rate limit errors and provides a
    more human-friendly explanation.
    """
    if GITHUB_ACCESS_TOKEN != "":
        url = urllib.request.Request(url)
        url.add_header('Authorization', f"Bearer {GITHUB_ACCESS_TOKEN}")
    try:
        return urllib.request.urlopen(url)
    except urllib.error.HTTPError as e:
        reset_ts = e.headers["x-ratelimit-reset"]
        if e.code != 403 or not reset_ts:
            raise
        reset_dt = datetime.datetime.fromtimestamp(int(reset_ts))
        reset_iso_utc = reset_dt.astimezone(datetime.timezone.utc).isoformat(' ')
        reset_iso_local = reset_dt.isoformat(' ')
        raise Exception(f"""
We have been rate-limited by GitHub. We can make API calls again at:
  {reset_iso_utc} UTC ({reset_iso_local} local time).
""" + f"""
You can try re-running the script and specifying an access token since authenticated GitHub API
requests have a higher rate limit.
""" if GITHUB_ACCESS_TOKEN == "" else "") from e

def github_last_release(repo):
    owner = repo["owner"]
    github_repo = repo["repo"]
    api_url = f"https://api.github.com/repos/{owner}/{github_repo}/releases/latest"
    return json.loads(github_urlopen(api_url).read())

def get_last_tag_name():
    repo_str = "hoodmane/workerd-pyodide"
    owner, repo_name = repo_str.split("/")
    repo = dict(owner=owner, repo=repo_name)
    return github_last_release(repo)["tag_name"]

def next_tag_name(tag):
    version_int = int(tag[1:]) + 1
    return f"{tag[0]}{version_int}"

if __name__ == "__main__":
    print(next_tag_name(get_last_tag_name()))
