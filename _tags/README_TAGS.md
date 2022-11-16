Add one file for each tag, with content like:

```
---
slug: virtualization
---
```

Convenient script to mass-add tags:

```sh
for tag in hardware usb-c lenovo yoga; do
  cat > _tags/"$tag".md << YAML
---
slug: $tag
---
YAML
done
```