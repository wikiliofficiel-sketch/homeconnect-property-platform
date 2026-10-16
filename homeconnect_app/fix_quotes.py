with open('lib/providers/app_provider.dart', encoding='utf-8') as f:
    content = f.read()

# Replace smart/curly apostrophes with regular ASCII apostrophe
fixed = content.replace('\u2019', "'")

with open('lib/providers/app_provider.dart', 'w', encoding='utf-8') as f:
    f.write(fixed)

print('Done - replaced smart apostrophes')
