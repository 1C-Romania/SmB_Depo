////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It splits a line into several lines according to a delimiter. Delimiter may have any length.
//
// Parameters:
//  String                 - String - Text with delimiters;
//  Delimiter            - String - Delimiter of text lines, minimum 1 symbol;
//  SkipBlankStrings - Boolean - Flag of necessity to show empty lines in the result.
//    If the parameter is not specified, the function works in the mode of compatibility with its previous version:
//     - for delimiter-space empty lines are not included in the result, for other
//       delimiters empty lines are included in the result.
//     E if Line parameter does not contain significant characters or doesn't contain any symbol (empty line),
//       then for delimiter-space the function result is an array containing one value ""
//       (empty line) and for other delimiters the function result is the empty array.
//  ReduceNonPrintableChars - Boolean - reduce the nonprinting characters around the edges of each found substring.
//
// Returns:
//  Array - array of rows.
//
// Examples:
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",") - it will return the array of 5 elements three of which  - empty
//  lines;
//  DecomposeStringIntoSubstringsArray(",one,,two,", ",", True) - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("one two ", " ") - it will return an array of two items;
//  DecomposeStringIntoSubstringArray("") - It returns an empty array;
//  DecomposeStringIntoSubstringsArray("",,False) - It returns an array with one element "" (empty line);
//  DecomposeStringIntoSubstringsArray("", " ") - It returns an array with one element "" (empty line);
//
Function DecomposeStringIntoSubstringsArray(Val String, Val Delimiter = ",", Val SkipBlankStrings = Undefined, ReduceNonPrintableChars = False) Export
	
	Result = New Array;
	
	// To ensure backward compatibility.
	If SkipBlankStrings = Undefined Then
		SkipBlankStrings = ?(Delimiter = " ", True, False);
		If IsBlankString(String) Then 
			If Delimiter = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = Find(String, Delimiter);
	While Position > 0 Do
		Substring = Left(String, Position - 1);
		If Not SkipBlankStrings Or Not IsBlankString(Substring) Then
			If ReduceNonPrintableChars Then
				Result.Add(TrimAll(Substring));
			Else
				Result.Add(Substring);
			EndIf;
		EndIf;
		String = Mid(String, Position + StrLen(Delimiter));
		Position = Find(String, Delimiter);
	EndDo;
	
	If Not SkipBlankStrings Or Not IsBlankString(String) Then
		If ReduceNonPrintableChars Then
			Result.Add(TrimAll(String));
		Else
			Result.Add(String);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction 

///  Merges array strings to a string with delimiters.
//
// Parameters:
//  Array      - Array - array of strings to be merged into one string;
//  Delimiter - String - any set of characters that will be used as delimeters.
//
// Returns:
//  String - String with delimiters.
// 
Function RowFromArraySubrows(Array, Delimiter = ",", ReduceNonPrintableChars = False) Export
	
	Result = "";
	
	For IndexOf = 0 To Array.UBound() Do
		Substring = Array[IndexOf];
		
		If ReduceNonPrintableChars Then
			Substring = TrimAll(Substring);
		EndIf;
		
		If TypeOf(Substring) <> Type("String") Then
			Substring = String(Substring);
		EndIf;
		
		If IndexOf > 0 Then
			Result = Result + Delimiter;
		EndIf;
		
		Result = Result + Substring;
	EndDo;
	
	Return Result;
	
EndFunction

// Defines if the character is a separator.
//
// Parameters:
//  CharCode      - Number  - checked character code;
//  WordSeparators - String - separators characters.
//
// Returns:
//  Boolean - true if character is a separator.
//
Function IsWordSeparator(CharCode, WordSeparators = Undefined) Export
	
	If WordSeparators <> Undefined Then
		Return Find(WordSeparators, Char(CharCode)) > 0;
	EndIf;
		
	Ranges = New Array;
	Ranges.Add(New Structure("min,Max", 48, 57)); 		// Digits
	Ranges.Add(New Structure("min,Max", 65, 90)); 		// big latin
	Ranges.Add(New Structure("min,Max", 97, 122)); 		// small latin
	Ranges.Add(New Structure("min,Max", 1040, 1103)); 	// cyrillic
	Ranges.Add(New Structure("min,Max", 1025, 1025)); 	// character YO
	Ranges.Add(New Structure("min,Max", 1105, 1105)); 	// character yo
	Ranges.Add(New Structure("min,Max", 95, 95)); 		// Char "_"
	
	For Each Range IN Ranges Do
		If CharCode >= Range.min AND CharCode <= Range.Max Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Breaks the row into several rows using the specified separators set.
// If the WordSeparators parameter is not specified, the words separator is any character that does not belong to Latin characters, Cyrillic characters, digits, underscores.
//
// Parameters:
//  String          - String - String that should be broken into words.
//  WordSeparators - String - String containing characters-separators.
//
//  Returns:
//      values list items of which - individual words.
//
// Example:
//  SplitStringIntoWordArray("one-@#two2_!three") will return array values: "one", "two2_", "three";
//  SplitStringIntoWordArray("one-@#two2_!three", "#@!_") will return array values: "one-", "two2", "three".
//
Function SplitStringIntoWordArray(Val String, WordSeparators = Undefined) Export
	
	Words = New Array;
	
	TextSize = StrLen(String);
	WordStart = 1;
	For Position = 1 To TextSize Do
		CharCode = CharCode(String, Position);
		If IsWordSeparator(CharCode, WordSeparators) Then
			If Position <> WordStart Then
				Words.Add(Mid(String, WordStart, Position - WordStart));
			EndIf;
			WordStart = Position + 1;
		EndIf;
	EndDo;
	
	If Position <> WordStart Then
		Words.Add(Mid(String, WordStart, Position - WordStart));
	EndIf;
	
	Return Words;
	
EndFunction

// It substitutes the parameters into the string. Max possible parameters quantity - 9.
// Parameters in the line are specified as %<parameter number>. Parameter numbering starts with one.
//
// Parameters:
//  LookupString  - String - String template with parameters (inclusions of "%ParameterName" type);
//  Parameter<n>        - String - substituted parameter.
//
// Returns:
//  String   - text string with substituted parameters.
//
// Example:
//  PlaceParametersIntoString(NStr("en='%1 went to %2';ru='%1 пошел в %2'"), "John", "Zoo") = "John went to the Zoo".
//
Function PlaceParametersIntoString(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined) Export
	
	UseAlternativeAlgorithm = 
		Find(Parameter1, "%")
		Or Find(Parameter2, "%")
		Or Find(Parameter3, "%")
		Or Find(Parameter4, "%")
		Or Find(Parameter5, "%")
		Or Find(Parameter6, "%")
		Or Find(Parameter7, "%")
		Or Find(Parameter8, "%")
		Or Find(Parameter9, "%");
		
	If UseAlternativeAlgorithm Then
		LookupString = SubstituteParametersInStringAlternateAlgorithm(LookupString, Parameter1,
			Parameter2, Parameter3, Parameter4, Parameter5, Parameter6, Parameter7, Parameter8, Parameter9);
	Else
		LookupString = StrReplace(LookupString, "%1", Parameter1);
		LookupString = StrReplace(LookupString, "%2", Parameter2);
		LookupString = StrReplace(LookupString, "%3", Parameter3);
		LookupString = StrReplace(LookupString, "%4", Parameter4);
		LookupString = StrReplace(LookupString, "%5", Parameter5);
		LookupString = StrReplace(LookupString, "%6", Parameter6);
		LookupString = StrReplace(LookupString, "%7", Parameter7);
		LookupString = StrReplace(LookupString, "%8", Parameter8);
		LookupString = StrReplace(LookupString, "%9", Parameter9);
	EndIf;
	
	Return LookupString;
EndFunction

// It substitutes the parameters into the string. Parameters quantity in row is not limited.
// Parameters in the line are specified as %<parameter number>. Parameter
// numbering starts with one.
//
// Parameters:
//  LookupString  - String - String template with parameters (listings of the type %1);
//  ParameterArray   - Array - Strings array that correspond to parameters in the substitution row.
//
// Returns:
//   String - String with input parameters.
//
// Example:
//  ParametersArray = New Array;
//  ParameterArray = ParameterArray.Add("John");
//  ParameterArray = ParameterArray.Add("Zoo");
//
//  String = PlaceParametersIntoString(NStr("en='%1 went to %2';ru='%1 пошел в %2'"), ParameterArray);
//
Function PlaceParametersIntoStringFromArray(Val LookupString, Val ParameterArray) Export
	
	ResultRow = LookupString;
	
	IndexOf = ParameterArray.Count();
	While IndexOf > 0 Do
		Value = ParameterArray[IndexOf-1];
		If Not IsBlankString(Value) Then
			ResultRow = StrReplace(ResultRow, "%" + Format(IndexOf, "NG="), Value);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return ResultRow;
	
EndFunction

// Substitutes parameters names for their values in the row template. Parameters in row are selected
// from both sides with brackets.
//
// Parameters:
//
//  StringPattern        - String    - String to which values should be input.
//  ValuesToInsert - Structure - values structure where key - parameter name without
//                                    special characters, value - input value.
//
// Returns:
//  String - String with the input values.
//
// Useful example:
//  SubstituteParametersInStringByName("Hello, [Name] [LastName].", New Structure("Surname,Name", "Pupkin", "John"));
//  Returns: Hello, John Doe.
Function SubstituteParametersInStringByName(Val StringPattern, ValuesToInsert) Export
	Result = StringPattern;
	For Each Parameter IN ValuesToInsert Do
		Result = StrReplace(Result, "[" + Parameter.Key + "]", Parameter.Value);
	EndDo;
	Return Result;
EndFunction

// Receives parameters values from row.
//
// Parameters:
//  ParameterString - String - String containing parameters each of which
//                              is a fragment of <Parameter name>=<Value> kind where:
//                                Parameter name - parameter name; 
//                                Value - its value. 
//                              Parts are separated by characters ';'.
//                              If a value contains space characters, it should be between
//                              double quotes (").
//                              ForExample:
//                               File=c:\Infobases\Trade; Usr=Director;
//
// Returns:
//  Structure - parameters structure where key - parameter name, value - value of the parameter.
//
Function GetParametersFromString(Val ParameterString) Export
	
	Result = New Structure;
	
	DoubleQuoteChar = Char(34); // (")
	
	SubstringArray = DecomposeStringIntoSubstringsArray(ParameterString, ";");
	
	For Each CurParameterString IN SubstringArray Do
		
		FirstEqualSignPosition = Find(CurParameterString, "=");
		
		// Receive parameter name
		ParameterName = TrimAll(Left(CurParameterString, FirstEqualSignPosition - 1));
		
		// Receive parameter value.
		ParameterValue = TrimAll(Mid(CurParameterString, FirstEqualSignPosition + 1));
		
		If  Left(ParameterValue, 1) = DoubleQuoteChar
			AND Right(ParameterValue, 1) = DoubleQuoteChar Then
			
			ParameterValue = Mid(ParameterValue, 2, StrLen(ParameterValue) - 2);
			
		EndIf;
		
		If Not IsBlankString(ParameterName) Then
			
			Result.Insert(ParameterName, ParameterValue);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Checks if row contains only digits.
//
// Parameters:
//  CheckString          - String - String for check.
//  IncludingLeadingZeros - Boolean - Check box of accounting leading zeros if True, then leading zeros are omitted.
//  IncludingUnits        - Boolean - Check box of accounting spaces if True, then spaces are ignored during the check.
//
// Returns:
//   Boolean - True - String contains only digits or empty, False - String contains other characters.
//
Function OnlyNumbersInString(Val CheckString, Val IncludingLeadingZeros = True, Val IncludingUnits = True) Export
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not IncludingUnits Then
		CheckString = StrReplace(CheckString, " ", "");
	EndIf;
		
	If IsBlankString(CheckString) Then
		Return True;
	EndIf;
	
	If Not IncludingLeadingZeros Then
		Position = 1;
		// If you take character from the row edge, an empty row will be returned.
		While Mid(CheckString, Position, 1) = "0" Do
			Position = Position + 1;
		EndDo;
		CheckString = Mid(CheckString, Position);
	EndIf;
	
	// If it contains only digits, then a row should appear as a result.
	// You can not check it using IsBlankString as there may be paces in the source row.
	Return StrLen(
		StrReplace( StrReplace( StrReplace( StrReplace( StrReplace(
		StrReplace( StrReplace( StrReplace( StrReplace( StrReplace( 
			CheckString, "0", ""), "1", ""), "2", ""), "3", ""), "4", ""), "5", ""), "6", ""), "7", ""), "8", ""), "9", "")
	) = 0;
	
EndFunction

// Checks if the row contains only Cyrillic characters.
//
// Parameters:
//  WithWordSeparators - Boolean - whether to consider the words separators or they are an exception.
//  AllowedChars - String for check.
//
// Returns:
//  Boolean - True if row contains only Cyrillic (or valid) characters or empty;
//           False if row contains other characters.
//
Function OnlyLatinInString(Val CheckString, Val WithWordSeparators = True, AllowedChars = "") Export
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(CheckString) Then
		Return True;
	EndIf;
	
	ValidCharacterCodes = New Array;
	ValidCharacterCodes.Add(1105); // yo
	ValidCharacterCodes.Add(1025); // YO
	
	For IndexOf = 1 To StrLen(AllowedChars) Do
		ValidCharacterCodes.Add(CharCode(Mid(AllowedChars, IndexOf, 1)));
	EndDo;
	
	For IndexOf = 1 To StrLen(CheckString) Do
		CharCode = CharCode(Mid(CheckString, IndexOf, 1));
		If ((CharCode < 1040) Or (CharCode > 1103)) 
			AND (ValidCharacterCodes.Find(CharCode) = Undefined) 
			AND Not (NOT WithWordSeparators AND IsWordSeparator(CharCode)) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Checks if the row contains only Latin characters.
//
// Parameters:
//  WithWordSeparators - Boolean - whether to consider the words separators or they are an exception.
//  AllowedChars - String for check.
//
// Returns:
//  Boolean - True if row contains only Latin (or valid) characters.;
//         - False if row contains other characters.
//
Function OnlyRomanInString(Val CheckString, Val WithWordSeparators = True, AllowedChars = "") Export
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(CheckString) Then
		Return True;
	EndIf;
	
	ValidCharacterCodes = New Array;
	
	For IndexOf = 1 To StrLen(AllowedChars) Do
		ValidCharacterCodes.Add(CharCode(Mid(AllowedChars, IndexOf, 1)));
	EndDo;
	
	For IndexOf = 1 To StrLen(CheckString) Do
		CharCode = CharCode(Mid(CheckString, IndexOf, 1));
		If ((CharCode < 65) Or (CharCode > 90 AND CharCode < 97) Or (CharCode > 122))
			AND (ValidCharacterCodes.Find(CharCode) = Undefined) 
			AND Not (NOT WithWordSeparators AND IsWordSeparator(CharCode)) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Deletes double quotes at the beginning and end of a row if any.
//
// Parameters:
//  String - input string;
//
// Returns:
//  String - String without double quotation marks.
// 
Function ContractDoubleQuotationMarks(Val String) Export
	
	While Left(String, 1) = """" Do
		String = Mid(String, 2); 
	EndDo; 
	
	While Right(String, 1) = """" Do
		String = Left(String, StrLen(String) - 1);
	EndDo;
	
	Return String;
	
EndFunction 

// Deletes the specified quantity of right characters from row.
//
// Parameters:
//  Text         - String - String where the last characters should be deleted;
//  CharsCount - Number  - quantity of deleted characters.
//
Procedure DeleteLatestCharInRow(Text, CharsCount = 1) Export
	
	Text = Left(Text, StrLen(Text) - CharsCount);
	
EndProcedure 

// Searches for character beginning from the row end.
//
// Parameters:
//  String - String - String where search is executed;
//  Char - String - required character. It is allowed to search for a row containing more than one character.
//
// Returns:
//  Number - character position in row. 
//          If the row does not contain the specified character, then 0 is returned.
//
Function FindCharFromEnd(Val String, Val Char) Export
	
	For Position = -StrLen(String) To -1 Do
		If Mid(String, -Position, StrLen(Char)) = Char Then
			Return -Position;
		EndIf;
	EndDo;
	
	Return 0;
		
EndFunction

// Checks whether a string is a unique identifier.
// The following string is defined as
// a unique identifier: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", where X = [0..9,a..f].
//
// Parameters:
//  IdentifierString - String - checked string.
//
// Returns:
//  Boolean - True if the passed row is a unique identifier.
Function ThisIsUUID(Val String) Export
	
	Pattern = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
	
	If StrLen(Pattern) <> StrLen(String) Then
		Return False;
	EndIf;
	For Position = 1 To StrLen(String) Do
		If CharCode(Pattern, Position) = 88 // X
			AND ((CharCode(String, Position) < 48 Or CharCode(String, Position) > 57) // 0..9
			AND (CharCode(String, Position) < 97 Or CharCode(String, Position) > 102) // a..f
			AND (CharCode(String, Position) < 65 Or CharCode(String, Position) > 70)) // A..F
			Or CharCode(Pattern, Position) = 45 AND CharCode(String, Position) <> 45 Then // -
				Return False;
		EndIf;
	EndDo;
	
	Return True;

EndFunction

// Generates row of duplicate characters of the specified length.
//
// Parameters:
//  Char      - String - character from which the row will be generated.
//  StringLength - Number  - result row required length.
//
// Returns:
//  String - String that consists only of duplicate characters.
//
Function GenerateStringOfCharacters(Val Char, Val StringLength) Export
	
	Result = "";
	For Counter = 1 To StringLength Do
		Result = Result + Char;
	EndDo;
	
	Return Result;
	
EndFunction

// Adds characters to the row to the left or right up to the specified length and returns it.
// Left and right insignificant characters are deleted. By default function adds 0 (zero) characters to the left in the row.
//
// Parameters:
//  String      - String - source row that should be expanded with characters;
//  StringLength - Number  - Required result row length.;
//  Char      - String - character that should expand row;
//  Mode       - String - Left or Right - mode of characters adding to the source row.
// 
// Returns:
//  String - String expanded with characters.
//
// Example 1:
// String = "1234"; StringLength = 10; Char = "0"; Mode = "Left"
// Return: "0000001234"
//
// Example 2:
// String = " 1234  "; StringLength = 10; Char = "#"; Mode = "RIGHT"
// Return: "1234######"
//
Function SupplementString(Val String, Val StringLength, Val Char = "0", Val Mode = "Left") Export
	
	// Character length should not be more than one.
	Char = Left(Char, 1);
	
	// Delete extreme spaces around row.
	String = TrimAll(String);
	
	CharToAddCount = StringLength - StrLen(String);
	
	If CharToAddCount > 0 Then
		
		StringToAdd = GenerateStringOfCharacters(Char, CharToAddCount);
		
		If Upper(Mode) = "LEFT" Then
			
			String = StringToAdd + String;
			
		ElsIf Upper(Mode) = "RIGHT" Then
			
			String = String + StringToAdd;
			
		EndIf;
		
	EndIf;
	
	Return String;
	
EndFunction

// Deletes end duplicate characters to the left or right in row.
//
// Parameters:
//  String      - String - source row from which it is required to delete extra duplicate characters;
//  Char      - String - required character for removal;
//  Mode       - String - Left or Right - mode of characters removing in the source row.
//
// Returns:
//  String - cropped string.
//
Function DeleteDuplicatedChars(Val String, Val Char, Val Mode = "Left") Export
	
	If Upper(Mode) = "LEFT" Then
		
		While Left(String, 1)= Char Do
			
			String = Mid(String, 2);
			
		EndDo;
		
	ElsIf Upper(Mode) = "RIGHT" Then
		
		While Right(String, 1)= Char Do
			
			String = Left(String, StrLen(String) - 1);
			
		EndDo;
		
	EndIf;
	
	Return String;
EndFunction

// Replaces characters in row.
//
// Parameters:
//  CharsToReplace - String - characters string, each of them requires replacement.;
//  String            - String - source row where characters replacement is required;
//  ReplacementChars     - String - String of characters and with each of those characters
//                               the ReplacedCharacters parameter characters should be replaced.
// 
//  Returns:
//   String - String after the characters replacements.
//
//  Note: the function is designed for simple cases, for example, for replacement
//  of Latin characters with the similar Cyrillic characters.
//
Function ReplaceSomeCharactersWithAnothers(CharsToReplace, String, ReplacementChars) Export
	
	Result = String;
	
	For CharacterNumber = 1 To StrLen(CharsToReplace) Do
		Result = StrReplace(Result, Mid(CharsToReplace, CharacterNumber, 1), Mid(ReplacementChars, CharacterNumber, 1));
	EndDo;
	
	Return Result;
	
EndFunction

// Converts Arabic number to Roman one.
//
// Parameters:
// ArabicNumber		  - number an integer from 0 to 999;
// UseLatinChars - Boolean, use Cyrillic or Latin characters as arabic digits.
//
// Returns:
// String - number in Roman notation.
//
// Example:
// ConvertNumberToRomanNotation(17)= "XVII".
//
Function ConvertNumberToRomanNumeral(ArabicNumber, UseLatinChars = True) Export
	
	RomanNumber	= "";
	ArabicNumber	= SupplementString(ArabicNumber, 3);
	
	If UseLatinChars Then
		c1 = "1"; c5 = "U"; c10 = "X"; c50 = "L"; c100 ="From"; c500 = "D"; c1000 = "M";
		
	Else
		c1 = "I"; c5 = "V"; c10 = "X"; c50 = "L"; c100 ="C"; c500 = "D"; c1000 = "M";
		
	EndIf;
	
	Units	= Number(Mid(ArabicNumber, 3, 1));
	Tens	= Number(Mid(ArabicNumber, 2, 1));
	Hundreds	= Number(Mid(ArabicNumber, 1, 1));
	
	RomanNumber = RomanNumber + ConvertDigitToRomanNumeral(Hundreds,   c100, c500, c1000);
	RomanNumber = RomanNumber + ConvertDigitToRomanNumeral(Tens, c10,  c50,  c100);
	RomanNumber = RomanNumber + ConvertDigitToRomanNumeral(Units, c1,   c5,   c10);
	
	Return RomanNumber;
	
EndFunction 

// Converts Roman number to Arabic one.
//
// Parameters:
// RomanNumber		  - String - number written with Roman numbers;
// UseLatinChars - Boolean - use Cyrillic or Latin characters as Arabic digits.
//
// Returns:
// Number.
//
// Example:
// ConvertNumberToArabicNotation("XVII") = 17.
//
Function ConvertDigitToArabicNumeral(RomanNumber, UseLatinChars = True) Export
	
	ArabicNumber=0;
	
	If UseLatinChars Then
		c1 = "1"; c5 = "U"; c10 = "X"; c50 = "L"; c100 ="From"; c500 = "D"; c1000 = "M";
		
	Else
		c1 = "I"; c5 = "V"; c10 = "X"; c50 = "L"; c100 ="C"; c500 = "D"; c1000 = "M";
		
	EndIf;
	
	RomanNumber = TrimAll(RomanNumber);
	CharsCount = StrLen(RomanNumber);
	
	For Ct=1 To CharsCount Do
		If Mid(RomanNumber,Ct,1) = c1000 Then
			ArabicNumber = ArabicNumber+1000;
		ElsIf Mid(RomanNumber,Ct,1) = c500 Then
			ArabicNumber = ArabicNumber+500;
		ElsIf Mid(RomanNumber,Ct,1) = c100 Then
			If (Ct < CharsCount) AND ((Mid(RomanNumber,Ct+1,1) = c500) OR (Mid(RomanNumber,Ct+1,1) = c1000)) Then
				ArabicNumber = ArabicNumber-100;
			Else
				ArabicNumber = ArabicNumber+100;
			EndIf;
		ElsIf Mid(RomanNumber,Ct,1) = c50 Then
			ArabicNumber = ArabicNumber+50;
		ElsIf Mid(RomanNumber,Ct,1) = c10 Then
			If (Ct < CharsCount) AND ((Mid(RomanNumber,Ct+1,1) = c50) OR (Mid(RomanNumber,Ct+1,1) = c100)) Then
				ArabicNumber = ArabicNumber-10;
			Else
				ArabicNumber = ArabicNumber+10;
			EndIf;
		ElsIf Mid(RomanNumber,Ct,1) = c5 Then
			ArabicNumber = ArabicNumber+5;
		ElsIf Mid(RomanNumber,Ct,1) = c1 Then
			If (Ct < CharsCount) AND ((Mid(RomanNumber,Ct+1,1) = c5) OR (Mid(RomanNumber,Ct+1,1) = c10)) Then
				ArabicNumber = ArabicNumber-1;
			Else
				ArabicNumber = ArabicNumber+1;
			EndIf;
		EndIf;
	EndDo;
	
	Return ArabicNumber;
	
EndFunction 

// Returns the text presentation of a number with measurement unit in the correct declension and number.
//
// Parameters:
//  Number                       - Number  - any integer number.
// MeasurementUnitInWordParameters - String - measurement unit writing variants in genitive
// 									   case for one, two and five units, separator - comma.
//
// Returns:
//  String - text presentation of units quantity, number is written in digits.
//
// Examples:
//  NumberInDigitsMeasurementUnitInWords(23,  "minute,minutes,minutes") = "23 minutes";
// 	NumberInDigitsMeasurementUnitInWords(15,  "minute,minutes,minutes") = "15 minutes".
Function NumberInDigitsMeasurementUnitInWords(Val Number, Val MeasurementUnitInWordParameters) Export

	Result = Format(Number,"NZ=0");
	
	PresentationArray = New Array;
	
	Position = Find(MeasurementUnitInWordParameters, ",");
	While Position > 0 Do
		Value = TrimAll(Left(MeasurementUnitInWordParameters, Position-1));
		MeasurementUnitInWordParameters = Mid(MeasurementUnitInWordParameters, Position + 1);
		PresentationArray.Add(Value);
		Position = Find(MeasurementUnitInWordParameters, ",");
	EndDo;
	
	If StrLen(MeasurementUnitInWordParameters) > 0 Then
		Value = TrimAll(MeasurementUnitInWordParameters);
		PresentationArray.Add(Value);
	EndIf;	
	
	If Number >= 100 Then
		Number = Number - Int(Number / 100)*100;
	EndIf;
	
	If Number > 20 Then
		Number = Number - Int(Number/10)*10;
	EndIf;
	
	If Number = 1 Then
		Result = Result + " " + PresentationArray[0];
	ElsIf Number > 1 AND Number < 5 Then
		Result = Result + " " + PresentationArray[1];
	Else
		Result = Result + " " + PresentationArray[2];
	EndIf;
	
	Return Result;	
			
EndFunction

// Clears HTML test from tags and returns unformatted text. 
//
// Parameters:
//  SourceText - String - HTML text.
//
// Returns:
//  String - text cleared from tags, scripts and titles.
//
Function ExtractTextFromHTML(Val SourceText) Export
	Result = "";
	
	Text = Lower(SourceText);
	
	// cut all that is not body
	Position = Find(Text, "<body");
	If Position > 0 Then
		Text = Mid(Text, Position + 5);
		SourceText = Mid(SourceText, Position + 5);
		Position = Find(Text, ">");
		If Position > 0 Then
			Text = Mid(Text, Position + 1);
			SourceText = Mid(SourceText, Position + 1);
		EndIf;
	EndIf;
	
	Position = Find(Text, "</body>");
	If Position > 0 Then
		Text = Left(Text, Position - 1);
		SourceText = Left(SourceText, Position - 1);
	EndIf;
	
	// cut out scripts
	Position = Find(Text, "<script");
	While Position > 0 Do
		ClosingTagPosition = Find(Text, "</script>");
		If ClosingTagPosition = 0 Then
			// Closing tag is not found - cut out the remaining text.
			ClosingTagPosition = StrLen(Text);
		EndIf;
		Text = Left(Text, Position - 1) + Mid(Text, ClosingTagPosition + 9);
		SourceText = Left(SourceText, Position - 1) + Mid(SourceText, ClosingTagPosition + 9);
		Position = Find(Text, "<script");
	EndDo;
	
	// cut out styles
	Position = Find(Text, "<style");
	While Position > 0 Do
		ClosingTagPosition = Find(Text, "</style>");
		If ClosingTagPosition = 0 Then
			// Closing tag is not found - cut out the remaining text.
			ClosingTagPosition = StrLen(Text);
		EndIf;
		Text = Left(Text, Position - 1) + Mid(Text, ClosingTagPosition + 8);
		SourceText = Left(SourceText, Position - 1) + Mid(SourceText, ClosingTagPosition + 8);
		Position = Find(Text, "<style");
	EndDo;
	
	// cut out all tags	
	Position = Find(Text, "<");
	While Position > 0 Do
		Result = Result + Left(SourceText, Position-1);
		Text = Mid(Text, Position + 1);
		SourceText = Mid(SourceText, Position + 1);
		Position = Find(Text, ">");
		If Position > 0 Then
			Text = Mid(Text, Position + 1);
			SourceText = Mid(SourceText, Position + 1);
		EndIf;
		Position = Find(Text, "<");
	EndDo;
	Result = Result + SourceText;
	RowArray = DecomposeStringIntoSubstringsArray(Result, Chars.LF, True, True);
	Return TrimAll(RowFromArraySubrows(RowArray, Chars.LF));
EndFunction

// Converts the source row to translit.
Function StringInLatin(Val String) Export
	Result = "";
	
	Map = AccordanceOfCyrillicAndLatinCodepages();
	
	PreviousSymbol = "";
	For Position = 1 To StrLen(String) Do
		Char = Mid(String, Position, 1);
		LatinSymbol = Map[Lower(Char)]; // Search for match ignoring the register.
		If LatinSymbol = Undefined Then
			// Other characters are left as they are.
			LatinSymbol = Char;
		Else
			If Char = Upper(Char) Then
				LatinSymbol = Title(LatinSymbol); // restore the register
			EndIf;
		EndIf;
		Result = Result + LatinSymbol;
		PreviousSymbol = LatinSymbol;
	EndDo;
	
	Return Result;
EndFunction

// Formats row according to the specified template.
// Possible selection tags values.:
// <b> String </b> - bolds row.
// <a href = "Ref"> String </a>
//
// Example:
// Min application version <b>1.1</b>. <a href = Update>Update</a> application.
//
// Returns:
//	FormattedString
Function FormattedString(Val String) Export
	
	RowsWithSelection = New ValueList;
	While Find(String, "<b>") <> 0 Do
		SelectionStart = Find(String, "<b>");
		RowBeforeOpeningTag = Left(String, SelectionStart - 1);
		RowsWithSelection.Add(RowBeforeOpeningTag);
		RowAfterOpeningTag = Mid(String, SelectionStart + 3);
		SelectionEnd = Find(RowAfterOpeningTag, "</b>");
		SelectedFragment = Left(RowAfterOpeningTag, SelectionEnd - 1);
		RowsWithSelection.Add(SelectedFragment,, True);
		RowAfterSelection = Mid(RowAfterOpeningTag, SelectionEnd + 4);
		String = RowAfterSelection;
	EndDo;
	RowsWithSelection.Add(String);
	
	RowsWithRefs = New ValueList;
	For Each RowPart IN RowsWithSelection Do
		
		String = RowPart.Value;
		
		If RowPart.Check Then
			RowsWithRefs.Add(String,, True);
			Continue;
		EndIf;
		
		SelectionStart = Find(String, "<a href = ");
		While SelectionStart <> 0 Do
			RowBeforeOpeningTag = Left(String, SelectionStart - 1);
			RowsWithRefs.Add(RowBeforeOpeningTag, );
			
			RowAfterOpeningTag = Mid(String, SelectionStart + 9);
			ClosingTag = Find(RowAfterOpeningTag, ">");
			
			Refs = TrimAll(Left(RowAfterOpeningTag, ClosingTag - 2));
			If Left(Refs, 1) = """" Then
				Refs = Mid(Refs, 2, StrLen(Refs) - 1);
			EndIf;
			If Right(Refs, 1) = """" Then
				Refs = Mid(Refs, 1, StrLen(Refs) - 1);
			EndIf;
			
			RowAfterRef = Mid(RowAfterOpeningTag, ClosingTag + 1);
			SelectionEnd = Find(RowAfterRef, "</a>");
			HyperlinkText = Left(RowAfterRef, SelectionEnd - 1);
			RowsWithRefs.Add(HyperlinkText, Refs);
			
			RowAfterSelection = Mid(RowAfterRef, SelectionEnd + 4);
			String = RowAfterSelection;
			
			SelectionStart = Find(String, "<a href = ");
		EndDo;
		RowsWithRefs.Add(String);
		
	EndDo;
	
	StringsArray = New Array;
	For Each RowPart IN RowsWithRefs Do
		
		If RowPart.Check Then
			StringsArray.Add(New FormattedString(RowPart.Value, New Font(,,True)));
		ElsIf Not IsBlankString(RowPart.Presentation) Then
			StringsArray.Add(New FormattedString(RowPart.Value,,,, RowPart.Presentation));
		Else
			StringsArray.Add(RowPart.Value);
		EndIf;
		
	EndDo;
	
	Return New FormattedString(StringsArray);
	
EndFunction

// Converts source row to a number.
//   Turns a row into a number without calling exceptions. Standard conversion function.
//   Number() strictly controls the absence of any characters except the numeric ones.
//
// Parameters:
//   SourceLine - String - String that is required to be reduced to a number.
//
// Returns:
//   Number - Received number.
//   Undefined - If row is not a number.
//
Function StringToNumber(Val SourceLine) Export
	SourceLine = TrimAll(SourceLine);
	Result = 0;
	SignsAfterComma = -1;
	NegativeSign = False;
	For CharacterNumber = 1 To StrLen(SourceLine) Do
		CharCode = CharCode(SourceLine, CharacterNumber);
		If CharCode = 32 Or CharCode = 160 Then // Space or nonbreaking space.
			// Skip (action is not required).
		ElsIf CharCode = 45 Or CharCode = 40 Then // Minus or an opening bracket.
			If Result <> 0 Then
				Return Undefined;
			EndIf;
			NegativeSign = True;
		ElsIf CharCode = 41 Then // Closing bracket.
			If Not NegativeSign Or Result = 0 Then // There was no opening bracket or no number.
				Return Undefined;
			EndIf;
			// Skip (action is not required).
		ElsIf CharCode = 44 Or CharCode = 46 Then // Comma or point.
			If SignsAfterComma <> -1 Then
				Return Undefined; // There was a separator already, therefore this is not a number.
			EndIf;
			SignsAfterComma = 0; // Start the calculation of decimals.
		ElsIf CharCode > 47 AND CharCode < 58 Then // Number.
			If SignsAfterComma <> -1 Then
				SignsAfterComma = SignsAfterComma + 1;
			EndIf;
			Number = CharCode - 48;
			Result = Result * 10 + Number;
		Else
			Return Undefined;
		EndIf;
	EndDo;
	
	If SignsAfterComma > 0 Then
		Result = Result / Pow(10, SignsAfterComma);
	EndIf;
	If NegativeSign Then
		Result = -Result;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Converts digits to the Roman numeric style. 
//
// Parameters:
// Digit - Number - digit from 0 to 9.
//  RomanOne, RomanFive, RomanTen - String - characters corresponding to the Roman numbers.
//
// Returned
// value String - digit in Roman notation.
//
// Example: 
// ConvertDigitToRomanNumeral(7,"I","V","X") = "VII".
//
Function ConvertDigitToRomanNumeral(Digit, RomanOne, RomanFive, RomanTen)
	
	RomanDigit="";
	If Digit = 1 Then
		RomanDigit = RomanOne
	ElsIf Digit = 2 Then
		RomanDigit = RomanOne + RomanOne;
	ElsIf Digit = 3 Then
		RomanDigit = RomanOne + RomanOne + RomanOne;
	ElsIf Digit = 4 Then
		RomanDigit = RomanOne + RomanFive;
	ElsIf Digit = 5 Then
		RomanDigit = RomanFive;
	ElsIf Digit = 6 Then
		RomanDigit = RomanFive + RomanOne;
	ElsIf Digit = 7 Then
		RomanDigit = RomanFive + RomanOne + RomanOne;
	ElsIf Digit = 8 Then
		RomanDigit = RomanFive + RomanOne + RomanOne + RomanOne;
	ElsIf Digit = 9 Then
		RomanDigit = RomanOne + RomanTen;
	EndIf;
	Return RomanDigit;
	
EndFunction

// It inserts parameters into the string taking into account that you can use substitution words %1, %2 etc. in  parameters
Function SubstituteParametersInStringAlternateAlgorithm(Val LookupString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined)
	
	Result = "";
	Position = Find(LookupString, "%");
	While Position > 0 Do 
		Result = Result + Left(LookupString, Position - 1);
		CharAfterPercent = Mid(LookupString, Position + 1, 1);
		SetParameter = "";
		If CharAfterPercent = "1" Then
			SetParameter =  Parameter1;
		ElsIf CharAfterPercent = "2" Then
			SetParameter =  Parameter2;
		ElsIf CharAfterPercent = "3" Then
			SetParameter =  Parameter3;
		ElsIf CharAfterPercent = "4" Then
			SetParameter =  Parameter4;
		ElsIf CharAfterPercent = "5" Then
			SetParameter =  Parameter5;
		ElsIf CharAfterPercent = "6" Then
			SetParameter =  Parameter6;
		ElsIf CharAfterPercent = "7" Then
			SetParameter =  Parameter7
		ElsIf CharAfterPercent = "8" Then
			SetParameter =  Parameter8;
		ElsIf CharAfterPercent = "9" Then
			SetParameter =  Parameter9;
		EndIf;
		If SetParameter = "" Then
			Result = Result + "%";
			LookupString = Mid(LookupString, Position + 1);
		Else
			Result = Result + SetParameter;
			LookupString = Mid(LookupString, Position + 2);
		EndIf;
		Position = Find(LookupString, "%");
	EndDo;
	Result = Result + LookupString;
	
	Return Result;
EndFunction

Function AccordanceOfCyrillicAndLatinCodepages()
	// Transliteration used in international passports 1997-2010.
	Map = New Map;
	Map.Insert("a","a");
	Map.Insert("b","b");
	Map.Insert("in","v");
	Map.Insert("g","g");
	Map.Insert("d","d");
	Map.Insert("e","e");
	Map.Insert("e","e");
	Map.Insert("G","zh");
	Map.Insert("z","z");
	Map.Insert("and","i");
	Map.Insert("y","y");
	Map.Insert("k","k");
	Map.Insert("l","l");
	Map.Insert("m","m");
	Map.Insert("n","n");
	Map.Insert("O","o");
	Map.Insert("p","p");
	Map.Insert("r","r");
	Map.Insert("From","s");
	Map.Insert("t","t");
	Map.Insert("u","u");
	Map.Insert("F","f");
	Map.Insert("x","kh");
	Map.Insert("cwt","ts");
	Map.Insert("ch","ch");
	Map.Insert("sh","sh");
	Map.Insert("shch","shch");
	Map.Insert("bj","""");
	Map.Insert("Y","y");
	Map.Insert("b",""); // skipped
	Map.Insert("e","e");
	Map.Insert("u","yu");
	Map.Insert("I","ya");
	
	Return Map;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// OUTDATED PROCEDURES AND FUNCTIONS

// Outdated. You should use RowFromSubrowsArray.
//
// Merges array strings to a string with delimiters.
//
// Parameters:
//  Array      - Array - array of strings to be merged into one string;
//  Delimiter - String - any set of characters that will be used as delimeters.
//
// Returns:
//  String - String with delimiters.
// 
Function GetStringFromSubstringArray(Array, Delimiter = ",") Export
	
	// Return value of the function.
	Result = "";
	
	For Each Item IN Array Do
		
		Substring = ?(TypeOf(Item) = Type("String"), Item, String(Item));
		
		SubstringSeparator = ?(IsBlankString(Result), "", Delimiter);
		
		Result = Result + SubstringSeparator + Substring;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
