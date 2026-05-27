// --- 根据天气文字 返回渐变背景 ---
export function getBackgroundByWeather(weather?: string): [string, number][] {
  /*这行代码的作用是先做空值兜底，再把结果转成字符串，避免在 weather 为 null/undefined 时调用字符串方法导致崩溃。
  (weather ?? '')：如果传入的 weather 是 null 或 undefined，就用空字符串替代；否则用它本身。.toString()：把兜底后的值安全地转成字符串，后续 includes 判断不会报错。

  `??` 是空值合并运算符（nullish coalescing）。写法 `(weather ?? '')` 的含义：

  - 如果 `weather` 是 `null` 或 `undefined`，结果取右边的空字符串 `''`。
  - 否则取 `weather` 自身。

  和 `||` 的区别：`||` 会把 `''`、`0`、`false` 也当成“假值”而替换掉；`??` 只针对 `null`/`undefined`，保留其它有效值。
  这样可以在 `toString()` / `includes` 之前兜底，避免 `weather` 未赋值时崩溃。
  */

  const safeWeather = (weather ?? '').toString();

  // 大雨：更深的蓝灰
  if (safeWeather.includes('大雨')) {
    return [['#0F2027', 0.0], ['#203A43', 1.0]];
  }

  // 小雨：偏蓝
  if (safeWeather.includes('小雨')) {
    return [['#4b6cb7', 0.0], ['#182848', 1.0]];
  }

  // 晴
  if (safeWeather.includes('晴')) {
    return [['#2980B9', 0.0], ['#6DD5FA', 1.0]];
  }

  // 阴 / 多云
  if (safeWeather.includes('阴') || safeWeather.includes('多云')) {
    return [['#bdc3c7', 0.0], ['#2c3e50', 1.0]];
  }

  // 默认
  return [['#B4A696', 0.0], ['#8F816E', 1.0]];
}