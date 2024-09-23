# Create a tunnel cloudflare and nginx and php
Set up a cloudflare tunnel, and nginx php letsencript website on the fly.

With this script you will create a cloudflare tunnel, launch an nginx and php server, create a php website that can be visited with htts thanks to the letsencript certificate that we will also request.

Just run this command

```
curl -o tunnel_fast.sh https://raw.githubusercontent.com/zaqueoae/instant_cloudflare_tunnel/refs/heads/main/tunnel_fast.sh?v=1
sudo bash ~/tunnel_fast.sh
```

Now simply access your domain from the browser and you will be able to see a "Hello world".
