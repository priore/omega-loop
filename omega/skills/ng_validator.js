const fs = require('fs');
const content = fs.readFileSync(process.argv[2], 'utf8');
const errors = [];
if (content.includes('$scope')) errors.push("Forbidden '$scope' usage found. Use component-driven architecture with controllerAs: '$ctrl'.");
if (content.includes('ng-repeat') && !content.includes('track by')) errors.push("Missing 'track by' clause in ng-repeat directive.");
if (content.includes('$on(') && !content.includes('$onDestroy')) errors.push("Event listener attached via $on without explicit cleanup in $onDestroy hook.");
if (errors.length) { errors.forEach(e => console.error(`[JS/NG ERROR] ${e}`)); process.exit(1); }
console.log("[JS/NG VALIDATION PASSED]");
