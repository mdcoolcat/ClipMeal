# LLM Cost Estimate

## Model & Pricing
- Model: Gemini 2.0 Flash
- Input: $0.10 / 1M tokens
- Output: $0.40 / 1M tokens

## LLM Call Paths Per Recipe

| # | Call | When | Input Tokens | Output Tokens |
|---|------|------|-------------|--------------|
| 1 | Bio detection | Video URLs with description | ~300 | ~5 |
| 2 | Extract from description text | Always for videos | ~1,100 | ~400 |
| 3 | Extract from author comments | If description extraction fails | ~1,100 | ~400 |
| 4 | Video file analysis (multimodal) | Last resort fallback | ~12,600 | ~400 |
| 5 | Website Gemini fallback | If structured scraping fails | ~3,000 | ~400 |

Video tokens: ~263 tokens/sec x ~30s avg TikTok + prompt overhead

## Estimated Path Distribution

| Path | Frequency | Calls | Input Tokens | Output Tokens |
|------|-----------|-------|-------------|--------------|
| Description has recipe | ~60% | 2 (bio + extract) | 1,400 | 405 |
| Needs comments too | ~25% | 4 (bio + desc + comments + bio) | 2,800 | 510 |
| Video file fallback | ~10% | 5 (all above + video) | 15,400 | 910 |
| Website Gemini fallback | ~5% | 1 | 3,000 | 400 |

## Weighted Average Per Recipe

| | Tokens | Cost |
|---|--------|------|
| Input | ~3,230 | $0.000323 |
| Output | ~482 | $0.000193 |
| **Total per recipe** | | **$0.0005** |

## Monthly Cost Projections

Assumptions: 10 recipes/user/week x 4.33 weeks/month = 43.3 recipes/user/month

| DAU | Recipes/Month | Monthly LLM Cost | Cost/User/Month |
|-----|--------------|------------------|----------------|
| 1,000 | 43,300 | ~$22 | $0.022 |
| 5,000 | 216,500 | ~$112 | $0.022 |
| 10,000 | 433,000 | ~$224 | $0.022 |
| 20,000 | 866,000 | ~$447 | $0.022 |

## Margin Analysis

At $2.99/month subscription (after Apple's 30% cut = $2.09 net):
- LLM cost per user: ~$0.022/month
- LLM cost as % of revenue: ~1%
