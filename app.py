"""日本株スクリーナー — TOPIX Core 30 を中心に一般的な財務指標で銘柄を比較するStreamlitアプリ。"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from urllib.parse import quote

import feedparser
import pandas as pd
import plotly.graph_objects as go
import streamlit as st
import yfinance as yf

JST = timezone(timedelta(hours=9))

st.set_page_config(
    page_title="日本株スクリーナー",
    page_icon="📈",
    layout="wide",
)

# 既定の対象銘柄(TOPIX Core 30 — 日本を代表する大型株30銘柄)
TOPIX_CORE30: dict[str, str] = {
    "7203.T": "トヨタ自動車",
    "6758.T": "ソニーグループ",
    "9984.T": "ソフトバンクグループ",
    "8306.T": "三菱UFJフィナンシャル・グループ",
    "9432.T": "日本電信電話",
    "6098.T": "リクルートホールディングス",
    "8316.T": "三井住友フィナンシャルグループ",
    "8035.T": "東京エレクトロン",
    "6861.T": "キーエンス",
    "6594.T": "ニデック",
    "9433.T": "KDDI",
    "7974.T": "任天堂",
    "4063.T": "信越化学工業",
    "9983.T": "ファーストリテイリング",
    "8058.T": "三菱商事",
    "7267.T": "本田技研工業",
    "6902.T": "デンソー",
    "4519.T": "中外製薬",
    "6981.T": "村田製作所",
    "8001.T": "伊藤忠商事",
    "6501.T": "日立製作所",
    "8031.T": "三井物産",
    "4502.T": "武田薬品工業",
    "7741.T": "HOYA",
    "4543.T": "テルモ",
    "6273.T": "SMC",
    "4661.T": "オリエンタルランド",
    "8411.T": "みずほフィナンシャルグループ",
    "6367.T": "ダイキン工業",
    "9434.T": "ソフトバンク",
}

# 株価に影響を与えそうなニュースカテゴリと検索キーワード
NEWS_TOPICS: dict[str, list[str]] = {
    "日本株市場": ["日経平均", "TOPIX", "東京株式市場"],
    "米国市場": ["NYダウ", "S&P500", "FRB", "米利上げ"],
    "為替": ["ドル円", "ユーロ円", "為替相場", "日銀"],
    "商品市況": ["原油価格", "WTI", "金価格"],
    "地政学・世界経済": ["中国経済", "中東情勢", "ウクライナ"],
}


def _to_pct(v):
    # yfinance は基本的に小数(0.05 = 5%)で返すが、
    # バージョンによってはすでに%表記(5)で返ることもあるので両対応。
    if v is None:
        return None
    return v * 100 if abs(v) < 1 else v


@st.cache_data(ttl=3600, show_spinner=False)
def fetch_stock_info(ticker: str) -> dict | None:
    try:
        t = yf.Ticker(ticker)
        info = t.info
        price = info.get("currentPrice") or info.get("regularMarketPrice")
        if not info or price is None:
            return None
        return {
            "コード": ticker.replace(".T", ""),
            "銘柄名": info.get("longName") or info.get("shortName") or ticker,
            "業種": info.get("industry") or "—",
            "株価": price,
            "PER": info.get("trailingPE"),
            "予想PER": info.get("forwardPE"),
            "PBR": info.get("priceToBook"),
            "配当利回り(%)": _to_pct(info.get("dividendYield")),
            "ROE(%)": _to_pct(info.get("returnOnEquity")),
            "営業利益率(%)": _to_pct(info.get("operatingMargins")),
            "売上成長率(%)": _to_pct(info.get("revenueGrowth")),
            "EPS成長率(%)": _to_pct(info.get("earningsGrowth")),
            "時価総額(億円)": (info.get("marketCap") or 0) / 1e8,
            "52週高値": info.get("fiftyTwoWeekHigh"),
            "52週安値": info.get("fiftyTwoWeekLow"),
        }
    except Exception:
        return None


@st.cache_data(ttl=3600, show_spinner=False)
def fetch_universe(tickers: tuple[str, ...]) -> pd.DataFrame:
    rows: list[dict] = []
    with ThreadPoolExecutor(max_workers=8) as ex:
        futures = [ex.submit(fetch_stock_info, t) for t in tickers]
        for f in as_completed(futures):
            r = f.result()
            if r is not None:
                rows.append(r)
    return pd.DataFrame(rows)


@st.cache_data(ttl=900, show_spinner=False)
def fetch_google_news(query: str, max_items: int = 10) -> list[dict]:
    # Google ニュース RSS は認証不要・無料。15分キャッシュ。
    url = (
        f"https://news.google.com/rss/search?q={quote(query)}"
        "&hl=ja&gl=JP&ceid=JP:ja"
    )
    try:
        feed = feedparser.parse(url)
    except Exception:
        return []
    items: list[dict] = []
    for entry in feed.entries[:max_items]:
        title_full = entry.get("title", "")
        # Google News のタイトルは "見出し - 出典" 形式
        if " - " in title_full:
            title, source = title_full.rsplit(" - ", 1)
        else:
            title, source = title_full, ""
        published_str = ""
        published = entry.get("published") or ""
        if published:
            try:
                dt = parsedate_to_datetime(published).astimezone(JST)
                published_str = dt.strftime("%m/%d %H:%M")
            except Exception:
                published_str = published
        items.append({
            "title": title,
            "link": entry.get("link", ""),
            "source": source,
            "published": published_str,
        })
    return items


def render_news_items(items: list[dict]) -> None:
    if not items:
        st.info("ニュースが見つかりませんでした")
        return
    for item in items:
        st.markdown(f"**[{item['title']}]({item['link']})**")
        meta_parts = [p for p in (item.get("source"), item.get("published")) if p]
        if meta_parts:
            st.caption(" · ".join(meta_parts))


def calculate_value_score(df: pd.DataFrame) -> pd.Series:
    # 簡易割安スコア(0〜100): 低PER・低PBR・高ROE・高配当利回りを総合評価。
    scores = pd.Series(0.0, index=df.index)
    per = df["PER"].fillna(30).clip(0, 30)
    scores += (30 - per) / 30 * 25
    pbr = df["PBR"].fillna(5).clip(0, 5)
    scores += (5 - pbr) / 5 * 25
    roe = df["ROE(%)"].fillna(0).clip(-20, 25)
    scores += (roe + 20) / 45 * 25
    div = df["配当利回り(%)"].fillna(0).clip(0, 6)
    scores += div / 6 * 25
    return scores.round(1)


def page_screening() -> None:
    st.title("📈 日本株スクリーナー")
    st.caption("TOPIX Core 30 を対象に一般的な財務指標で比較・スクリーニング")

    with st.expander("⚠️ 免責事項", expanded=False):
        st.warning(
            "本ツールは情報提供のみが目的であり、投資助言・推奨ではありません。"
            "データは Yahoo Finance 経由で取得しており、誤りや欠損が含まれる場合があります。"
            "投資判断はご自身の責任で行ってください。"
        )

    with st.sidebar:
        st.header("対象銘柄")
        use_default = st.checkbox("TOPIX Core 30 を含める", value=True)
        custom_input = st.text_area(
            "追加銘柄(4桁コード・改行区切り)",
            placeholder="例:\n7011\n6920\n8267",
            height=120,
        )

        st.header("絞り込み条件")
        per_max = st.slider("PER 上限", 0, 50, 20)
        pbr_max = st.slider("PBR 上限", 0.0, 5.0, 2.0, 0.1)
        roe_min = st.slider("ROE 下限(%)", -10, 30, 8)
        div_min = st.slider("配当利回り 下限(%)", 0.0, 6.0, 0.0, 0.1)

    tickers: list[str] = []
    if use_default:
        tickers.extend(TOPIX_CORE30.keys())
    for line in custom_input.splitlines():
        code = line.strip()
        if code.isdigit() and len(code) == 4:
            t = f"{code}.T"
            if t not in tickers:
                tickers.append(t)

    if not tickers:
        st.info("サイドバーで対象銘柄を指定してください")
        return

    with st.spinner(f"{len(tickers)}銘柄のデータを取得中…(初回30秒〜1分)"):
        df = fetch_universe(tuple(sorted(tickers)))

    if df.empty:
        st.error("データを取得できませんでした")
        return

    df["割安スコア"] = calculate_value_score(df)

    filtered = df[
        (df["PER"].fillna(999) <= per_max)
        & (df["PBR"].fillna(999) <= pbr_max)
        & (df["ROE(%)"].fillna(-999) >= roe_min)
        & (df["配当利回り(%)"].fillna(-1) >= div_min)
    ].copy()

    st.subheader(f"結果: {len(filtered)} / {len(df)} 銘柄")

    display_cols = [
        "コード", "銘柄名", "業種", "株価",
        "PER", "PBR", "配当利回り(%)", "ROE(%)",
        "営業利益率(%)", "売上成長率(%)", "EPS成長率(%)",
        "時価総額(億円)", "割安スコア",
    ]
    sorted_df = filtered[display_cols].sort_values("割安スコア", ascending=False)

    st.dataframe(
        sorted_df,
        use_container_width=True,
        hide_index=True,
        column_config={
            "株価": st.column_config.NumberColumn(format="¥%.0f"),
            "PER": st.column_config.NumberColumn(format="%.1f"),
            "PBR": st.column_config.NumberColumn(format="%.2f"),
            "配当利回り(%)": st.column_config.NumberColumn(format="%.2f"),
            "ROE(%)": st.column_config.NumberColumn(format="%.1f"),
            "営業利益率(%)": st.column_config.NumberColumn(format="%.1f"),
            "売上成長率(%)": st.column_config.NumberColumn(format="%.1f"),
            "EPS成長率(%)": st.column_config.NumberColumn(format="%.1f"),
            "時価総額(億円)": st.column_config.NumberColumn(format="%.0f"),
            "割安スコア": st.column_config.ProgressColumn(
                "割安スコア", format="%.1f", min_value=0, max_value=100,
            ),
        },
    )

    st.caption(
        "**割安スコア**: PER・PBR・ROE・配当利回りを各25点で配分した簡易指標(0〜100)。"
        "あくまで一次スクリーニング用で、実際の投資判断は決算書・事業内容を必ず確認してください。"
    )


def page_detail() -> None:
    st.title("🔍 個別銘柄詳細")

    code = st.text_input("銘柄コード(4桁)", value="7203", max_chars=4)
    if not (code.isdigit() and len(code) == 4):
        st.info("4桁の銘柄コードを入力してください")
        return

    ticker = f"{code}.T"
    info = fetch_stock_info(ticker)

    if info is None:
        st.error(f"{ticker} のデータを取得できませんでした")
        return

    st.subheader(f"{info['銘柄名']} ({info['コード']})")
    st.caption(f"業種: {info['業種']}")

    def show_metric(col, label, val, fmt):
        col.metric(label, fmt.format(val) if val is not None else "—")

    cols = st.columns(4)
    show_metric(cols[0], "株価", info["株価"], "¥{:,.0f}")
    show_metric(cols[1], "PER", info["PER"], "{:.1f}倍")
    show_metric(cols[2], "PBR", info["PBR"], "{:.2f}倍")
    show_metric(cols[3], "配当利回り", info["配当利回り(%)"], "{:.2f}%")

    cols = st.columns(4)
    show_metric(cols[0], "ROE", info["ROE(%)"], "{:.1f}%")
    show_metric(cols[1], "営業利益率", info["営業利益率(%)"], "{:.1f}%")
    show_metric(cols[2], "売上成長率", info["売上成長率(%)"], "{:.1f}%")
    show_metric(cols[3], "EPS成長率", info["EPS成長率(%)"], "{:.1f}%")

    cols = st.columns(3)
    show_metric(cols[0], "時価総額", info["時価総額(億円)"], "{:,.0f}億円")
    show_metric(cols[1], "52週高値", info["52週高値"], "¥{:,.0f}")
    show_metric(cols[2], "52週安値", info["52週安値"], "¥{:,.0f}")

    st.subheader("株価チャート(過去1年)")
    try:
        hist = yf.Ticker(ticker).history(period="1y")
        if hist.empty:
            st.info("株価履歴を取得できませんでした")
            return
        hist["MA25"] = hist["Close"].rolling(25).mean()
        hist["MA75"] = hist["Close"].rolling(75).mean()

        fig = go.Figure()
        fig.add_trace(go.Candlestick(
            x=hist.index,
            open=hist["Open"], high=hist["High"],
            low=hist["Low"], close=hist["Close"],
            name="株価",
        ))
        fig.add_trace(go.Scatter(
            x=hist.index, y=hist["MA25"],
            name="25日移動平均", line=dict(color="orange", width=1.5),
        ))
        fig.add_trace(go.Scatter(
            x=hist.index, y=hist["MA75"],
            name="75日移動平均", line=dict(color="purple", width=1.5),
        ))
        fig.update_layout(
            xaxis_rangeslider_visible=False,
            height=500,
            margin=dict(l=0, r=0, t=20, b=0),
            legend=dict(orientation="h", yanchor="bottom", y=1.02),
        )
        st.plotly_chart(fig, use_container_width=True)
    except Exception as e:
        st.error(f"チャート取得エラー: {e}")

    st.subheader("関連ニュース")
    # 日本語の銘柄名で検索(TOPIX Core 30 の日本語名を優先)
    search_name = TOPIX_CORE30.get(ticker, info["銘柄名"])
    news_items = fetch_google_news(search_name, max_items=8)
    render_news_items(news_items)


def page_news() -> None:
    st.title("📰 市場ニュース")
    st.caption("Google ニュースから株価に影響を与えそうな記事を取得します(15分キャッシュ)")

    with st.sidebar:
        st.header("ニュース設定")
        selected = st.multiselect(
            "表示カテゴリ",
            list(NEWS_TOPICS.keys()),
            default=list(NEWS_TOPICS.keys()),
        )
        max_per_category = st.slider("カテゴリあたりの件数", 3, 15, 5)
        if st.button("🔄 再取得"):
            fetch_google_news.clear()
            st.rerun()

    if not selected:
        st.info("サイドバーでカテゴリを選択してください")
        return

    for category in selected:
        st.subheader(category)
        query = " OR ".join(NEWS_TOPICS[category])
        items = fetch_google_news(query, max_items=max_per_category)
        render_news_items(items)
        st.divider()


page = st.sidebar.radio(
    "メニュー", ["スクリーニング", "個別銘柄詳細", "市場ニュース"]
)
if page == "スクリーニング":
    page_screening()
elif page == "個別銘柄詳細":
    page_detail()
else:
    page_news()
