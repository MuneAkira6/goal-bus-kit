# goal-bus-kit

> **English summary** — A toolkit for running a long, multi-goal Claude Code task unattended: a worker
> session executes goals, a long-lived "bus" session reviews every goal boundary and writes the next
> goal's instructions, and two Stop hooks keep the loop honest by reading files, not conversation. It
> is a clean re-implementation of a method I designed and ran 18 times at work; this repository holds
> the hooks, their end-to-end selftests (Git Bash, and Ubuntu with both gawk and mawk), the goal-pack
> templates, 30 lessons, and a real run on a small example. The notification gap is left open on purpose.

## 何を示すか

- 複数の goal にまたがる長い作業を、人が張り付かずに進める方式（長命バス方式）を、どのリポジトリにも入れられる形で作り直したものです。
- 完了の判定を会話ではなくファイル（判定表）で行い、安いチェックを先に、高い審査は goal の境界だけに置きます。異常時はすべて止まって人を待ちます。
- 実務で起きた「音のしない失敗」を 30 件の教訓にまとめ、それぞれを自己テストで守っています（`[L1]`〜`[L30]` のラベル）。

## 背景

実務では、マルチテナント B2B SaaS の開発でこの方式を 18 回運用しました（2026 年 8〜9 月）。経緯と実務での数字は、事例集の[「無人で goal を回す」](https://github.com/MuneAkira6/engineering-case-studies/blob/main/04-unattended-goal-bus.md)にまとめています。実務のコードは非公開なので、このリポジトリは仕組みを読み直したうえで、すべて書き直したものです。

## 設計

```
hooks/goal-bus.sh        リレー（Stop hook）。--status / --seed / --notify / --next / --recover / --reset / --selftest
hooks/evidence-gate.sh   証拠門（Stop hook）。--check / --selftest
hooks/lib/common.sh      両 hook とテストが共有する関数（署名・境界・裁決の解析、状態、CLI の呼び出し口）
hooks/lib/tables.awk     判定表の唯一のパーサー（gawk・mawk の両方で動く書き方）
hooks/bus.config.sh      唯一の設定の入口（すべて GOALBUS_* 環境変数で上書き可能）
hooks/bin/start-worker.sh  ワーカーの起動・再開の唯一の入口
hooks/bin/watch.sh       成果物だけを見る監視（トランスクリプトの文字列は探さない）
hooks/selftest/          偽の CLI（fake-claude）を使った、端から端までの自己テスト
templates/               BUS-PROTOCOL / goal-brief / runbook / PROGRESS / BUS-MEMORY / settings.hooks.json
docs/method.md           方式の説明（役割、流れ、使いどころ、二つの形態、通知の穴）
docs/lessons.md          教訓 30 件（症状 → 原因 → 防護 → このキットでの実装）
examples/toy-run/        小さな題材での実走記録
```

主な設計判断は次のとおりです。

- **判定はファイルで。** goal の途中のターンは、hook が PROGRESS.md の空欄を数えて駆動します。表が全部埋まることだけが出口です。
- **安いチェックが先。** 証拠門は数秒で終わり、バスを起こしません。バスを起こすのは境界だけです。
- **呼び出し口は一つ。** バスを起こすコマンドは `claude_call()`、ワーカーは `worker_call()` の中にしかありません。人の入口も `--notify` を通ります。
- **パーサーは一つ。** hook もテストも同じ `tables.awk` と同じ正規表現を使うので、テストが緑なのに挙動が変わる、ということが起きません。
- **移植性。** 区間正規表現、POSIX 文字クラス、gawk 専用の関数を使いません。Ubuntu の既定の awk（mawk）でも黙って盲目になりません。
- **モデルは設定で。** バスとワーカーのモデルを別々に指定できます（既定は Opus の 1M コンテキスト）。交代の閾値は 1M の窓を前提にしており、200k の窓での変え方も設定ファイルに書いています。

## 動かし方

前提：bash（Windows なら Git Bash）、jq、awk（gawk か mawk）、coreutils の timeout、Claude Code CLI。

1. このリポジトリを取得する：`git clone https://github.com/MuneAkira6/goal-bus-kit`
2. 自分のリポジトリに入れる：`bash goal-bus-kit/install.sh <your-repo> --task specs/my-task --name "My task" --goals "G0 G1 G2"`（両方の自己テストもここで走ります）
3. `specs/my-task/` の goal 包（brief・protocol・runbook・PROGRESS・memory）の `{{…}}` を埋め、最初の goal の指示を `g0-instructions.md` に書く
4. `.claude/settings.local.json` がもともとあった場合は、表示された 2 つのブロックを手で合流させる
5. 自分でブランチを作る
6. バスを起こす：`bash .claude/hooks/goal-bus.sh --seed`
7. 閂を立てる：`touch specs/my-task/.gate-on specs/my-task/.relay-on`
8. ワーカーを起動する：`bash .claude/hooks/bin/start-worker.sh --file specs/my-task/g0-instructions.md`
9. 見張る：`bash .claude/hooks/bin/watch.sh`（状態は `bash .claude/hooks/goal-bus.sh --status`）
10. 止まったら `BUS-LOG.md` と `BUS-REVIEWS.md` を読み、goal の境界で commit し、閂を外す

キット自体のテストは `bash tests/run-all.sh` で、awk を固定するときは `GOALBUS_AWK=mawk bash tests/run-all.sh` のようにします。

## 結果

自己テスト（このキットで実測、2026-10-05、`bash tests/run-all.sh` を各環境で 1 回）：

| 環境 | リレー | 証拠門 | テンプレート / 導入 / 起動 / 教訓の網羅 | 所要時間 |
|---|---|---|---|---|
| Windows 11 / Git Bash 5.2.37 / gawk 5.3.2 / jq 1.8.1 | 170 成功・1 スキップ（mawk が無いため） | 34 成功・1 スキップ（同） | 28 / 14 / 9 / 30 件すべて | 810 秒 |
| Ubuntu 24.04（WSL2）/ bash 5.2.21 / gawk 5.2.1 / jq 1.8.1 | 171 成功 | 35 成功 | 28 / 14 / 9 / 30 件すべて | 24 秒 |
| Ubuntu 24.04（WSL2）/ bash 5.2.21 / mawk 1.3.4 / jq 1.8.1 | 171 成功 | 35 成功 | 28 / 14 / 9 / 30 件すべて | 12 秒 |
| Ubuntu 20.04（Linux ホスト）/ bash 5.0.17 / gawk 5.0.1 / jq 1.6 | 171 成功 | 35 成功 | 28 / 14 / 9 / 30 件すべて | 27 秒 |
| Ubuntu 20.04（Linux ホスト）/ bash 5.0.17 / mawk 1.3.4 / jq 1.6 | 171 成功 | 35 成功 | 28 / 14 / 9 / 30 件すべて | 26 秒 |

shellcheck 0.11.0（`-S warning`）の指摘は 0 件です。教訓 30 件は、ラベル付きの 160 件のテストで守られています。

小さな題材での実走（[examples/toy-run/](examples/toy-run/)、2026-09-29、Linux ホスト）：3 goal・判定 24 行がすべて PASS、バスの審査 3 回（REJECT 0）、人の介入 1 回、所要 30 分 39 秒でした。cost_usd（CLI が報告する API 換算値）はバス側 $3.62、ワーカー側 $6.44 です。台帳（BUS-LOG / BUS-REVIEWS / PROGRESS / BUS-MEMORY）はそのまま収めています。介入の原因（hook に認証トークンが届かなかった）を含め、実走で見つかった 3 件はキットを直してテストを付けました。

実務での実績（実務での実測値。コードは非公開）：18 回の運用、最初の本番運用で 6 goal・裁決 9 回（うち REJECT 3 回）・判定 100 行・FAIL 0・人の介入 1 回。詳しくは事例集を参照してください。

## 制約・既知の限界

- **通知の穴は開いたままです。** リレーが止まっても誰にも知らせません。Stop hook は「何も起きていない」ことを検出できず、届くことを確かめられた通知チャネルもないため、通知の仕組みは同梱していません（`docs/method.md` 第 10 節）。
- **バスの手抜きは機械で防げません。** 人が `BUS-REVIEWS.md` を抜き取りで監査します（runbook 第 6 節）。
- ブランチ作成を止める機械的な防護はありません（必要なら deny に追加してください）。
- Windows の Git Bash ではプロセスの起動が遅く、全体テストに約 13 分かかります（Ubuntu では 12〜27 秒）。hook そのものの 1 回の処理も、Windows では数秒かかります。
- 計画停止（`PAUSE_AFTER`）の後の再開は、人がコマンドを 1 つ打つ前提です。
- 共有ホストで設定ディレクトリを分けて動かすと、CLI が Stop hook に認証トークンを渡さないことがあります。`GOALBUS_ENV_FILE` で補います（`hooks/bus.config.sh` のコメント、`docs/method.md` 第 5 節）。

### 実務で実施した点／このリポジトリで追加した点

- **実務で実施した点**：2 つの Stop hook、判定表による駆動、証拠門、上限、コンテキストの計測と交代、`--status` / `--recover` / `--notify`、監視スクリプト、テンプレート、教訓 30 件、Linux ホストでの運用。
- **このリポジトリで追加した点**：偽の CLI による端から端までのテスト、gawk と mawk の両方での CI、未知の判定語の拒否、最後の署名行による判定、交代時の引き継ぎ書の指紋比較と `BUS-READY` の確認、計画停止と `--next`、`--seed`、ワーカー起動の一元化、証拠門の通算カウンタ、判定表の英語の列名。実走を受けて、バスを起こせなかったときの理由の台帳記録、`GOALBUS_ENV_FILE` の文書化、再開後の監視の誤報の修正。

## 作り方

設計・判定・検収は私が行い、実装の大部分は AI エージェント（Claude Code）が担当しました。実務での運用記録と教訓を読み直し、仕組みを理解したうえで、コード・テンプレート・文書をすべて書き直しています。

公開の前に、フックの実装層（関数名・変数名・設定項目名・状態ファイル名と、いくつかの処理の書き方）をもう一度書き直しました。仕組みとプロトコル（進捗行、`BUS-VERDICT`、判定語、フックのファイル名と引数）は変わっていません。[examples/toy-run/](examples/toy-run/) と、このポートフォリオのほかのリポジトリにある `goal-pack/` は、書き直す前の版で実行した記録です。

---

設計・レビュー・検証：So Ryo ／ 実装：AI エージェント（Claude Code）との協働
