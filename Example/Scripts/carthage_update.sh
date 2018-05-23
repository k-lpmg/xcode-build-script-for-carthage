cd ..

rm -rf Carthage
carthage update --platform iOS

cd Scripts
ruby carthage_build_setup.rb

rm -rf ~/Library/Developer/Xcode/DerivedData/*
