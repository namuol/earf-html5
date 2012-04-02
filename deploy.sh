cake build
git checkout gh-pages
cp build/* .
git commit -am 'auto-deploy'
git push origin gh-pages
git checkout master
