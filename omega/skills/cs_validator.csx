using System;
using System.IO;

var filePath = Args[0];
var content = File.ReadAllText(filePath);
bool failed = false;

if (content.Contains("Task.Run") && (content.Contains("Stream") || content.Contains("HttpClient"))) {
    Console.WriteLine("[C# ERROR] Avoid Task.Run for I/O bound operations. Use native async/await APIs.");
    failed = true;
}
if (!content.Contains("ReadOnlySpan") && content.Contains("string.Substring")) {
    Console.WriteLine("[C# PERFORMANCE TIP] Consider ReadOnlySpan<char> instead of string.Substring to avoid allocations.");
}
if (failed) Environment.Exit(1);
Console.WriteLine("[C# VALIDATION PASSED]");
