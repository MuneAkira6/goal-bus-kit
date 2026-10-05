# toy-run：小さな題材での実走

> **English summary** — A real, unattended run of goal-bus-kit: three goals and 24 judged rows to build
> `csvq`, a tiny CSV query CLI in TypeScript, on a Linux host (2026-09-29). All 24 rows passed, the bus
> reviewed three times with no REJECT, and one human intervention was needed: the Stop hook's call to
> the bus was "Not logged in" because the CLI did not pass its token to the hook, which the kit now
> documents (`GOALBUS_ENV_FILE`). The real ledgers are committed unedited in `specs/csvq/`.
> Bus side `cost_usd` $3.62, worker side $6.44 (CLI-reported, API-equivalent). Wall clock 30 min 39 s.

## 何を示すか

このキットを新しいリポジトリに入れ、3 つの goal（環境と契約の凍結 → 中核機能 → エラー処理・性能・仕上げ）を人が張り付かずに回した記録です。題材は小さくしてあります。どの受け入れ条件も、コマンドの出力を引用して判定できるように作っています。

台帳は手を加えずにそのまま収めています：判定表 [PROGRESS.md](specs/csvq/PROGRESS.md)、リレーの記録 [BUS-LOG.md](specs/csvq/BUS-LOG.md)、審査の全文 [BUS-REVIEWS.md](specs/csvq/BUS-REVIEWS.md)、バスの記憶 [BUS-MEMORY.md](specs/csvq/BUS-MEMORY.md)、AS-BUILT に書き直された契約 [SCOPE.md](specs/csvq/SCOPE.md)。ホストのパスは台帳に一度も現れなかったため、伏せ字の処理も不要でした。

この実走は、公開前にキットの実装層（関数名・変数名・設定項目名・状態ファイル名）を書き直す前の版で行いました。`specs/csvq/` の文書に出てくる `.bus-armed` などの名前や `awk -v MODE=…` のような呼び出しは、当時の名前のままです。今の版での名前は [hooks/bus.config.sh](../../hooks/bus.config.sh) と本文の手順にあります。`specs/csvq/.gitignore` だけは、今の版で走らせ直せるように新しい名前にしています。

## 題材

`app/` の `csvq` は、CSV を読み、列の選択（`--select`）、行の絞り込み（`--where`）、件数（`--count`）、合計（`--sum`）、JSON 出力（`--format json`）を行う小さな CLI です。使い方は [app/README.md](app/README.md) にあります（14 個の例は、ワーカーとバスがそれぞれ実際の出力と突き合わせました）。

判定表は 24 行です。G0 が環境の条件 5 行、G1 が AC 6 件と検査 3 行、G2 が AC 5 件と締めくくり 5 行です。

## 動かし方

手元の PC で動かすなら、これだけです。

```bash
bash examples/toy-run/launch.sh
```

初回はキットの hook をここに導入して両方の自己テストを走らせ、バスを起こし、閂を立てて、ワーカーを前面で起動します。別の端末から `cd examples/toy-run && bash .claude/hooks/bin/watch.sh 60` で見張れます。

今回の実走は、PC の電源と切り離すために Linux ホストで行いました。ホストでは次の 3 点を足しています。

```bash
export CLAUDE_CONFIG_DIR=<実行専用のディレクトリ>   # アカウントの MCP・skills・記憶を読み込ませない
export GOALBUS_ENV_FILE=<source 行だけのファイル>   # hook に届かない認証トークンを戻す（bus.config.sh を参照）
setsid nohup bash examples/toy-run/launch.sh >> launch.log 2>&1 < /dev/null &   # SSH を切っても続く
```

## 結果

| 項目 | 値 |
|---|---|
| 実行日 | 2026-09-29 |
| 環境 | Linux ホスト（Ubuntu 20.04 / bash 5.0.17 / gawk 5.0.1 / jq 1.6）、Node v24.19.0、pnpm 11.0.9（`packageManager` で固定）、Claude Code 2.1.233 |
| モデル | バス・ワーカーとも `opus[1m]`（この CLI では claude-opus-5[1m] に解決） |
| キット | 公開前に実装層を書き直す前の版（導入時の自己テスト：リレー 162・証拠門 35、すべて成功）。仕組みとプロトコルは今の版と同じです |
| goal / 判定行 | 3 goal / 24 行：PASS 24、FAIL・BLOCKED・DEFERRED 0 |
| バスの審査 | 3 回（G0 PASS、G1 PASS、G2 DONE）、REJECT 0、バスの交代 0 |
| 証拠門のブロック | 0 回 |
| バスのコンテキスト | 最後の審査の時点で 99,138 トークン |
| cost_usd（CLI が報告する API 換算値） | バス側 $3.62（審査 3 回。バスの起動分は含まず）、ワーカー側 $6.44（2 プロセス、計 73 ターン） |
| 所要時間 | 30 分 39 秒（17:33:53〜18:04:32。うち約 4 分は下記の停止） |
| 人の介入 | 1 回 |

**流れ**（時刻はホストの時計）：

- 17:33:53 発車。導入で両方の自己テストが通り、17:34:17 にバスとワーカーが起動
- 17:37:16 ワーカーが G0 を終えた（5 行すべて PASS）。hook がバスを起こしたが「Not logged in」で失敗し、リレーは設計どおり止まって人を待った
- 17:41:16 人の介入：原因を調べ、`GOALBUS_ENV_FILE` を設定して、同じワーカーを再開した（「G0 の境界をもう一度報告してほしい」という短い指示を添えた）
- 17:43:53 G0 審査 #1：PASS
- 17:52:01 G1 審査 #2：PASS
- 18:03:56 G2 審査 #3：DONE
- 18:04:32 ワーカーのプロセスが終了

### バスが審査でしたこと

- **自分で確かめた。** 3 回とも、ワーカーの報告を読むだけでなくコマンドを自分で再実行しました。G0 では、フィクスチャのレコード数と列数を元のファイルから数え直しています。G1 の期待値（大阪の 2 件、合計 1650）は、コードが一行もない段階で自分で導いていました。
- **資料よりも観察を取った。** goal-brief の「確認済みの事実」は、goal 包を書いた私の PC の値（Windows、Node v24.15.0、インストール約 25 秒）でした。ワーカーがこれを指摘し、バスは「観察が資料に勝つ」と認め、自分の記憶を実測値に書き直しました。
- **次の goal の出発点を測った。** G1 の後、まだ扱っていない境界ケースを自分で試し、そのうち 9 項目（存在しない列、数値でない合計、壊れた CSV など）を「今はこう動く」という形で G2 の指示に書きました。
- **契約にあって AC 行のない条項も試した。** G2 では、行の列数の不一致や数値でない値の合計なども自分で試し、G1 の機能が壊れていないかも回帰として確かめました。

### AC-11 の裁定

AC-11 は「1 万件のファイルに `--where` と `--sum` をかけ、3 回の中央値が 1 秒未満」です。

- **ワーカー**：`node src/cli.ts` を直接起動すると中央値 136 ms、`pnpm csvq` 経由では 1,296 ms でした。差は pnpm の起動の費用だとして PASS と判定しましたが、両方の数字を証拠に残し、裁定をバスに委ねました。
- **バス**：自分で 1 万件を作り直して測り（node 149 ms、pnpm 1,284 ms）、対照として 5 件のフィクスチャでも pnpm 経由なら 1,290 ms かかることを確かめました。pnpm の起動費用はデータ量に関係なく一定で、その読み方ではどんな実装も通りません。そこで「この行が測っているのは csvq の速さだ」として PASS を維持しました。
- **振り返り**：AC がどの起動方法で測るのかを書いていなかったのは、goal 包を書いた私の落ち度です。バスも goal 包の直すべき点として挙げたため、テンプレートに注意書きを足しました（`templates/PROGRESS.md`）。

### 人がしたこと

- 発車前の確認（ホストの自己テスト、実際の CLI 呼び出しによる認証の確認、他の実行との占有の確認）、発車、上記の介入 1 回。
- **審査の抜き取り監査**（runbook 第 6 節の 9 項目）：3 回の審査すべてで、疑わしい兆候は 0 件でした。気になった点は 1 つだけです。G1 の審査で、バスが確認のために `app/package.json` を一時的に書き換えていました（元に戻し、自分から報告しています）。確認は一時ディレクトリで行うべきでした。
- **別の環境での再検証**：Windows 11 / Git Bash で `pnpm install --frozen-lockfile`、`pnpm test`（39 件成功）、`pnpm lint`、`pnpm typecheck` が通ることを確かめました。`csvq fixtures/basic.csv --where city=Osaka --sum amount` は `1650` を、`csvq fixtures/broken.csv` は終了コード 2 と `unterminated quote on line 3` を返しました。

## 実走で見つかったこと

キットの側（どれも偽の CLI を使う自己テストでは出なかったもので、いまは直してテストを付けています。詳しくは [docs/lessons.md](../../docs/lessons.md) の「実走（toy-run）で見つかったこと」）：

- **hook が CLI 自身の認証トークンを受け取らなかった。** 設定ディレクトリは届いたので会話は見つかったが、認証できなかった。`GOALBUS_ENV_FILE` を文書化し、起こすのに失敗したときは理由を台帳に書くようにしました。
- **再開の直後、監視が「終わった」と誤報する状態だった。** 前のプロセスの結果行がログに残っていたためです。最後の見出し行の後だけを見るようにしました。
- **起動スクリプトが、ワーカーを起動する前に終わっていた**（ホストでの実走の前、手元での最初の起動）。状態表示を `| head` で切ったことによる SIGPIPE でした。

goal 包の側（私が書いたもの。実走の記録として、ここではそのまま残しています）：

- goal-brief の「確認済みの事実」を、実走に使うマシンで確かめていなかった。
- 性能の AC が、どの起動方法で測るのかを書いていなかった。

## 準備の段階で分かったこと

- **pnpm 11 の供給網の設定は実際に効きます。** 許可リスト（`allowBuilds`）を空にして `strictDepBuilds` を有効にしたまま、ビルドスクリプトを持つ依存を入れようとすると、`ERR_PNPM_IGNORED_BUILDS` でインストールが失敗しました。vitest 5 と TypeScript 7 の組み合わせでは、ビルドスクリプトを要求する依存がないため、許可リストは空のままにしています。
- **設定の自動移行が lint を黙って空にしていました。** Biome 2.5 の `biome migrate` は、旧形式の `recommended: true` を `"preset": "none"` に書き換えました。`debugger;` を置いた検査用のファイルでは、`none` のときは何も検出されず（終了コード 0）、`recommended` にすると検出されます（終了コード 1）。緑に見えるのに何も検査していない、という教訓 L19 と同じ形なので、`"preset": "recommended"` を明示しています。

---

設計・レビュー・検証：So Ryo ／ 実装：AI エージェント（Claude Code）との協働
