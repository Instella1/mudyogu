#!/usr/bin/env python3
"""게임 로딩 검증: 콘솔 에러 + 스크린샷"""
import asyncio
import sys
from playwright.async_api import async_playwright

BASE = "http://127.0.0.1:8089"

CASES = [
    ("hanilnam-life", "/games/hanilnam-life/index.html", "hanilnam"),
    ("haniljeon", "/games/haniljeon/index.html", "haniljeon"),
    ("pokequiz", "/games/pokequiz/index.html", "pokequiz"),
    ("tower-drop", "/games/tower-drop/index.html", "towerdrop"),
]

VIEWPORTS = [
    ("desktop", 1280, 800),
    ("mobile", 390, 844),
]


async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for name, path, slug in CASES:
            for vp_name, w, h in VIEWPORTS:
                page = await browser.new_page(
                    viewport={"width": w, "height": h},
                    device_scale_factor=2,
                )
                errors, warnings = [], []
                page.on("console", lambda m: (
                    errors.append(m.text) if m.type == "error"
                    else warnings.append(m.text) if m.type == "warning" else None
                ))
                page.on("pageerror", lambda e: errors.append(f"PAGEERROR: {e}"))

                await page.goto(BASE + path, wait_until="networkidle", timeout=45000)
                await page.wait_for_timeout(2500)

                out = f"/tmp/shot_{slug}_{vp_name}.png"
                await page.screenshot(path=out, full_page=False)

                # 페이지 내 텍스트 일부 확인
                body_len = await page.evaluate("document.body.innerText.length")
                print(f"[{name}/{vp_name}] text={body_len} errors={len(errors)}")

                for e in errors[:6]:
                    print(f"   ❌ {e[:220]}")
                await page.close()
        await browser.close()


asyncio.run(run())
