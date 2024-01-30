npx hardhat run ./scripts/00-deployAccount.ts
echo "....................................................."
npx hardhat run ./scripts/01-deployRegistry.ts
echo "....................................................."
npx hardhat run ./scripts/02-deployProfile.ts
echo "....................................................."
npx hardhat run ./scripts/03-updateConstants.ts
echo "....................................................."
npx hardhat run ./scripts/10-deployContactList.ts
echo "....................................................."
npx hardhat run ./scripts/11-updateConstants.ts
echo "....................................................."
npx hardhat run ./scripts/20-deployTLCC.ts
echo "....................................................."
npx hardhat run ./scripts/99-updateApiAndWeb.ts
echo "....................................................."