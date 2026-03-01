# Publishing Generated Outputs

If you use `cdd-ruby` to generate a Ruby API client, you should automate its publication to keep it in sync with the server API.

## GitHub Actions Cronjob

Create a workflow `.github/workflows/update_client.yml`:

```yaml
name: Update Client
on:
  schedule:
    - cron: "0 0 * * *"
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: curl -O https://api.yoursite.com/openapi.json
      - run: gem install cdd-ruby
      - run: cdd-ruby from_openapi -i openapi.json -u lib/client.rb
      - run: |
          git config --global user.name "GitHub Action"
          git config --global user.email "action@github.com"
          git add lib/client.rb
          git commit -m "Update client"
          git push
```
