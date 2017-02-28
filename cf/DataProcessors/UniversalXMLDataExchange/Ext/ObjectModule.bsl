#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// USED VARIABLE NAME ABBREVIATIONS (ABBREVIATIONS)

//  OCR  - objects conversion rule.
//  PCR  - object properties conversion rule.
//  PGCR - object properties group conversion rule.
//  VCR  - object values conversion rule.
//  DDR  - data export rule.
//  DCR  - data clearing rule.

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// HELPER MODULE VARIABLES FOR ALGORITHMS WRITING (COMMON FOR EXPORT AND UPLOAD)

Var Conversion  Export;  // Conversion properties structure (Name, Id, exchange event handlers).

Var Algorithms    Export;  // Structure containing used algorithms.
Var Queries      Export;  // Structure containing used queries.
Var AdditionalInformationProcessors Export;  // Structure containing used external data processors.

Var Rules      Export;  // Structure containing references to OCR.

Var Managers    Export;  // Match containing the fields Name, TypeName, RefTypeAsString, Manager, MDObject, ORC.
Var ManagersForExchangePlans Export;
Var ExchangeFile Export;            // Consistently written/read exchange file.

Var AdditionalInformationProcessorParameters Export;  // Structure containing parameters using external data processors.

Var ParametersInitialized Export;  // If True, then required conversion parameters are initialized.

Var mDataLogFile Export; // File for keeping data exchange protocol.
Var CommentObjectProcessingFlag Export;

Var EventHandlerExternalDataProcessor Export; // The "ExternalDataProcessorsManager" object for
                                                   // handler export procedures call while debugging import/export.

Var CommonProcedureFunctions;  // Variable stores reference to the specified data processor instance - ThisObject.
                              // It is required for export procedures call from event handlers.

Var mHandlerParameterTemplate; // Tabular document with handler parameters.
Var mCommonProcedureFunctionsTemplate;  // Text document with comments, global variables and
                                    // wrappers of general procedures and functions.

Var mDataProcessingModes; // Structure containing modes of this wrapper usage.
Var DataProcessingMode;   // Contains current value of the data processor mode.

Var mAlgorithmDebugModes; // Structure containing algorithms debugging modes.
Var IntegratedAlgorithms; // Structure containing algorithms with integrated code of nested algorithms.

Var HandlerNames; // Structure containing names of all exchange rule handlers.


////////////////////////////////////////////////////////////////////////////////
// CHECK BOX OF GLOBAL DATA PROCESSORS PRESENSE

Var HasBeforeObjectExportGlobalHandler;
Var HasAfterObjectExportGlobalHandler;

Var HasBeforeConvertObjectGlobalHandler;

Var HasBeforeObjectImportGlobalHandler;
Var HasAftertObjectImportGlobalHandler;

Var TargetPlatformVersion;
Var TargetPlatform;

////////////////////////////////////////////////////////////////////////////////
// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND EXPORT)

Var deStringType;                  // Type("String")
Var deBooleanType;                  // Type("Boolean")
Var deNumberType;                   // Type("Number")
Var deDateType;                    // Type("Date")
Var deValueStorageType;       // Type("ValueStorage")
Var deUUIDType; // Type("UUID")
Var deBinaryDataType;          // Type("BinaryData")
Var deAccumulationRecordTypeType;   // Type("AccrualMovementKind")
Var deObjectDeletionType;         // Type("ObjectRemoval")
Var deAccountTypeType;			    // Type("AccountType")
Var deTypeType;			  		    // Type("Type")
Var deMapType;		    // Type("Map").

Var odNodeTypeXML_EndElement  Export;
Var odNodeTypeXML_StartElement Export;
Var odNodeTypeXML_Text          Export;

Var EmptyDateValue Export;

Var deMessages;             // Matching. Key - error code, Value - error description.

Var mExchangeRuleTemplateList Export;


////////////////////////////////////////////////////////////////////////////////
// EXPORT DATA PROCESSOR MODULE VARIABLES
 
Var mExportedObjectCounter Export;   // Number - exported objects counter.
Var mSnCounter Export;   // Number - NPP counter
Var mXMLDocument;                          // Helper DOM-XML document used while creating xml nodes.
Var mPropertyConversionRuleTable;      // ValueTable - template to create table
                                             //                   structure by copying.
Var mXMLRules;                           // Xml-String containing exchange rules description.
Var mTypesForTargetString;


////////////////////////////////////////////////////////////////////////////////
// VARIABLES OF UPLOAD DATA PROCESSOR MODULE
 
Var mImportedObjectCounter Export;// Number - imported objects counter.

Var mExchangeFileAttributes Export;       // Structure. After opening the file, it contains exchange file attributes according to the format.

Var ImportedObjects Export;         // Matching. Key - object NPP
                                          // in file, Value - ref to the imported object.
Var ImportedGlobalObjects Export;
Var ImportedObjectToStoreCount Export;  // Quantity of stored imported objects after which Match ImportedObjects is cleared.
Var RememberImportedObjects Export;

Var mExtendedSearchParameterMap;
Var mConversionRuleMap; // Match to determine object conversion rule by the object type.

Var mDataImportDataProcessor Export;

Var mEmptyTypeValueMap;
Var mTypeDescriptionMap;

Var mExchangeRulesReadOnImport Export;

Var mDataExportCallStack;

Var mDataTypeMapForImport;

Var mNotWrittenObjectGlobalStack;

Var EventsAfterParameterImport Export;

Var CurrentNestingLevelExportByRule;

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURES FOR ALGORITHM WRITING

////////////////////////////////////////////////////////////////////////////////
// WORK WITH STRINGS

// Breaks a row into two parts: up to subrow and after.
//
// Parameters:
//  Str          - parsed row;
//  Delimiter  - subrow-separator:
//  Mode        - 0 - a separator in the returned subrows is not included;
//                 1 - separator is included into a left subrow;
//                 2 - separator is included to a right subrow.
//
// Returns:
//  Right part of the row - up to delimiter character
// 
Function SeparateBySeparator(Str, Val Delimiter, Mode=0) Export

	RightPart         = "";
	SplitterPos      = Find(Str, Delimiter);
	SeparatorLength    = StrLen(Delimiter);
	If SplitterPos > 0 Then
		RightPart	 = Mid(Str, SplitterPos + ?(Mode=2, 0, SeparatorLength));
		Str          = TrimAll(Left(Str, SplitterPos - ?(Mode=1, -SeparatorLength + 1, 1)));
	EndIf;

	Return(RightPart);

EndFunction

// Converts values from string to array using the specified separator.
//
// Parameters:
//  Str            - Parsed string.
//  Delimiter    - subrow separator.
//
// Returns:
//  Array of values
// 
Function ArrayFromString(Val Str, Delimiter=",") Export

	Array      = New Array;
	RightPart = SeparateBySeparator(Str, Delimiter);
	
	While Not IsBlankString(Str) Do
		Array.Add(TrimAll(Str));
		Str         = RightPart;
		RightPart = SeparateBySeparator(Str, Delimiter);
	EndDo; 

	Return(Array);
	
EndFunction

// It splits a line into several lines according to a delimiter. Delimiter may have any length.
//
// Parameters:
//  String                 - String - Text with delimiters;
//  Delimiter            - String - Delimiter of text lines, minimum 1 symbol;
//  SkipBlankStrings - Boolean - Flag of necessity to show empty lines in the result.
//    If the parameter is not specified, the function works in the mode of compatibility with its previous version:
//     - for delimiter-space empty lines are not included in the result, for other
//       delimiters empty lines are included in the result.
//     E if Line parameter does not contain significant characters or does not contain any symbol (empty
//       line), then for delimiter-space the function result is an array containing one value
//       "" (empty line) and for other delimiters the function result is the empty array.
//
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
Function DecomposeStringIntoSubstringsArray(Val String, Val Delimiter = ",", Val SkipBlankStrings = Undefined) Export
	
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
			Result.Add(Substring);
		EndIf;
		String = Mid(String, Position + StrLen(Delimiter));
		Position = Find(String, Delimiter);
	EndDo;
	
	If Not SkipBlankStrings Or Not IsBlankString(String) Then
		Result.Add(String);
	EndIf;
	
	Return Result;
	
EndFunction 

// Returns number string without character prefixes.
// ForExample:
//  GetRowNumberWithoutPrefixes ("UT0000001234") = "0000001234"
// 
// Parameters:
//  Number - String - number from which it is required to calculate function result.
// 
//  Returns:
//  number string without character prefixes.
//
Function GetStringNumberWithoutPrefixes(Number) Export
	
	NumberWithoutPrefixes = "";
	Ct = StrLen(Number);
	
	While Ct > 0 Do
		
		Char = Mid(Number, Ct, 1);
		
		If (Char >= "0" AND Char <= "9") Then
			
			NumberWithoutPrefixes = Char + NumberWithoutPrefixes;
			
		Else
			
			Return NumberWithoutPrefixes;
			
		EndIf;
		
		Ct = Ct - 1;
		
	EndDo;
	
	Return NumberWithoutPrefixes;
	
EndFunction

// Parses string excluding prefix and numeric part from it.
//
// Parameters:
//  Str            - String. Parsed string;
//  NumericalPart  - Number. Variable to which string numeric part is returned;
//  Mode          - String. If there is "Number", then it returns a numeric part, otherwise, - Prefix.
//
// Returns:
//  String prefix
//
Function GetPrefixNumberOfNumber(Val Str, NumericalPart = "", Mode = "") Export

	NumericalPart = 0;
	Prefix = "";
	Str = TrimAll(Str);
	Length   = StrLen(Str);
	
	StringNumberWithoutPrefix = GetStringNumberWithoutPrefixes(Str);
	StringPartLength = StrLen(StringNumberWithoutPrefix);
	If StringPartLength > 0 Then
		NumericalPart = Number(StringNumberWithoutPrefix);
		Prefix = Mid(Str, 1, Length - StringPartLength);
	Else
		Prefix = Str;	
	EndIf;

	If Mode = "Number" Then
		Return(NumericalPart);
	Else
		Return(Prefix);
	EndIf;

EndFunction

// Reduces number (code) to the required length. Prefix and
// number numeric part are excluded, the rest of the
// space between the prefix and the number is filled in with zeros.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters:
//  Str          - converted string;
//  Length        - required string length.
//
// Returns:
//  String       - code or number reduced to the required length.
// 
Function CastNumberToLength(Val Str, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "") Export

	If IsBlankString(Str)
		OR StrLen(Str) = Length Then
		
		Return Str;
		
	EndIf;
	
	Str             = TrimAll(Str);
	IncomingNumberLength = StrLen(Str);

	NumericalPart   = "";
	LineNumberPrefix   = GetPrefixNumberOfNumber(Str, NumericalPart);
	
	FinalPrefix = ?(IsBlankString(Prefix), LineNumberPrefix, Prefix);
	ResultingPrefixLength = StrLen(FinalPrefix);
	
	NumericPartString = Format(NumericalPart, "NG=0");
	NumericPartLength = StrLen(NumericPartString);

	If (Length >= IncomingNumberLength AND AddZerosIfLengthNotLessCurrentNumberLength)
		OR (Length < IncomingNumberLength) Then
		
		For TemporaryVariable = 1 To Length - ResultingPrefixLength - NumericPartLength Do
			
			NumericPartString = "0" + NumericPartString;
			
		EndDo;
	
	EndIf;
	
	// cut extra characters
	NumericPartString = Right(NumericPartString, Length - ResultingPrefixLength);
		
	Result = FinalPrefix + NumericPartString;

	Return Result;

EndFunction

// Adds substring to the prefix of number or code.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters:
//  Str          - String. Number or code;
//  Additive      - substring added to the prefix;
//  Length        - Required result row length.;
//  Mode        - "Left" - substring is added left to the prefix, otherwise, - right.
//
// Returns:
//  String       - number or code to the prefix of which the specified substring is added.
//
Function AddToPrefix(Val Str, Additive = "", Length = "", Mode = "Left") Export

	Str = TrimAll(Format(Str,"NG=0"));

	If IsBlankString(Length) Then
		Length = StrLen(Str);
	EndIf;

	NumericalPart   = "";
	Prefix         = GetPrefixNumberOfNumber(Str, NumericalPart);

	If Mode = "Left" Then
		Result = TrimAll(Additive) + Prefix;
	Else
		Result = Prefix + TrimAll(Additive);
	EndIf;

	While Length - StrLen(Result) - StrLen(Format(NumericalPart, "NG=0")) > 0 Do
		Result = Result + "0";
	EndDo;

	Result = Result + Format(NumericalPart, "NG=0");

	Return Result;

EndFunction

// Expands string with the specified character up to the specified length.
//
// Parameters: 
//  Str          - expanded string;
//  Length        - required length of the resulting string;
//  Than          - character which expands string.
//
// Returns:
//  String expanded with the specified character up to the specified length.
//
Function deAddToString(Str, Length, Than = " ") Export

	Result = TrimAll(Str);
	While Length - StrLen(Result) > 0 Do
		Result = Result + Than;
	EndDo;

	Return(Result);

EndFunction


////////////////////////////////////////////////////////////////////////////////
// WORK WITH DATA

// Returns string - name of the passed enumeration value.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters:
//  Value     - enumeration value.
//
// Returns:
//  String       - name of the passed enumeration value.
//
Function deEnumValueName(Value) Export

	MDObject       = Value.Metadata();
	ValueIndex = Enums[MDObject.Name].IndexOf(Value);

	Return MDObject.EnumValues[ValueIndex].Name;

EndFunction

// Determines whether the passed value is filled in.
//
// Parameters: 
//  Value       - value filling of which should be checked.
//
// Returns:
//  True         - value is not filled in, false - else.
//
Function deBlank(Value, IsNULL=False) Export

	// First, primitive types
	If Value = Undefined Then
		Return True;
	ElsIf Value = NULL Then
		IsNULL   = True;
		Return True;
	EndIf;
	
	ValueType = TypeOf(Value);
	
	If ValueType = deValueStorageType Then
		
		Result = deBlank(Value.Get());
		Return Result;
		
	ElsIf ValueType = deBinaryDataType Then
		
		Return False;
		
	Else
		
		// For the rest ones consider the value empty
		// if it equals to the default value of its type.
		Return Not ValueIsFilled(Value);
		
	EndIf;
	
EndFunction

// Returns TypeDescription object containing the specified type.
//  
// Parameters:
//  TypeValue - srtring with type name or value of the Type type.
//  
// Returns:
//  TypeDescription
//
Function deDescriptionType(TypeValue) Export
	
	TypeDescription = mTypeDescriptionMap[TypeValue];
	
	If TypeDescription = Undefined Then
		
		TypeArray = New Array;
		If TypeOf(TypeValue) = deStringType Then
			TypeArray.Add(Type(TypeValue));
		Else
			TypeArray.Add(TypeValue);
		EndIf; 
		TypeDescription	= New TypeDescription(TypeArray);
		
		mTypeDescriptionMap.Insert(TypeValue, TypeDescription);
		
	EndIf;
	
	Return TypeDescription;
	
EndFunction

// Returns empty (default) value of the specified type.
//
// Parameters:
//  Type          - srtring with type name or value of the Type type.
//
// Returns:
//  Empty value of the specified type.
// 
Function deGetBlankValue(Type) Export

	EmptyTypeValue = mEmptyTypeValueMap[Type];
	
	If EmptyTypeValue = Undefined Then
		
		EmptyTypeValue = deDescriptionType(Type).AdjustValue(Undefined);
		mEmptyTypeValueMap.Insert(Type, EmptyTypeValue);
		
	EndIf;
	
	Return EmptyTypeValue;

EndFunction

Function CheckExistenceOfRef(Ref, Manager, FoundByUUIDObject,
	SearchByUUIDQueryString)
	
	Try
			
		If IsBlankString(SearchByUUIDQueryString) Then
			
			FoundByUUIDObject = Ref.GetObject();
			
			If FoundByUUIDObject = Undefined Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		Else
			// This is the search mode by ref - it is enough to make
			// a query to the infobase template for query PropertiesStructure.SearchString.
			
			Query = New Query();
			Query.Text = SearchByUUIDQueryString + "  Ref = &Ref ";
			Query.SetParameter("Ref", Ref);
			
			QueryResult = Query.Execute();
			
			If QueryResult.IsEmpty() Then
			
				Return Manager.EmptyRef();
				
			EndIf;
			
		EndIf;
		
		Return Ref;	
		
	Except
			
		Return Manager.EmptyRef();
		
	EndTry;
	
EndFunction

// Executes simple search for infobase object by the specified property.
//
// Parameters:
//  Manager       - searched object manager;
//  Property       - property according to which search is
// executed: Name, Code, Name or Indexed attribute name;
//  Value       - property value according to which you should search for object.
//
// Returns:
//  Found infobase object.
//
Function FindObjectByProperty(Manager, Property, Value,
	FoundByUUIDObject,
	CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined,
	SearchByUUIDQueryString = "") Export
	
	If Property = "Name" Then
		
		Return Manager[Value];
		
	ElsIf Property = "Code" Then
		
		Return Manager.FindByCode(Value);
		
	ElsIf Property = "Description" Then
		
		Return Manager.FindByDescription(Value, TRUE);
		
	ElsIf Property = "Number" Then
		
		Return Manager.FindByNumber(Value);
		
	ElsIf Property = "{UUID}" Then
		
		RefByUUID = Manager.GetRef(New UUID(Value));
		
		Ref = CheckExistenceOfRef(RefByUUID, Manager, FoundByUUIDObject,
			SearchByUUIDQueryString);
			
		Return Ref;
		
	ElsIf Property = "{PredefinedItemName}" Then
		
		Try
			
			Ref = Manager[Value];
			
		Except
			
			Ref = Manager.FindByCode(Value);
			
		EndTry;
		
		Return Ref;
		
	Else
		
		// You can find it only by attribute except for strings of a custom length and values storage.
		If Not (Property = "Date"
			OR Property = "Posted"
			OR Property = "DeletionMark"
			OR Property = "Owner"
			OR Property = "Parent"
			OR Property = "IsFolder") Then
			
			Try
				
				OpenEndedString = DefineThisParameterIsOfUnlimitedLength(CommonPropertyStructure, Value, Property);
				
			Except
				
				OpenEndedString = False;
				
			EndTry;
			
			If Not OpenEndedString Then
				
				Return Manager.FindByAttribute(Property, Value);
				
			EndIf;
			
		EndIf;
		
		ObjectReference = FindItemUsingQuery(CommonPropertyStructure, CommonSearchProperties, , Manager);
		Return ObjectReference;
		
	EndIf;
	
EndFunction

// Executes simple search for infobase object by the specified property.
//
// Parameters:
//  Str            - String - property value according to
// which search is executed object;
//  Type            - searched oject type;
//  Property       - String - property name according to which you should search for object.
//
// Returns:
//  Found infobase object.
//
Function deGetValueByString(Str, Type, Property = "") Export

	If IsBlankString(Str) Then
		Return New(Type);
	EndIf; 

	Properties = Managers[Type];

	If Properties = Undefined Then
		
		TypeDescription = deDescriptionType(Type);
		Return TypeDescription.AdjustValue(Str);
		
	EndIf;

	If IsBlankString(Property) Then
		
		If Properties.TypeName = "Enum" Then
			Property = "Name";
		Else
			Property = "{PredefinedItemName}";
		EndIf;
		
	EndIf;
	
	Return FindObjectByProperty(Properties.Manager, Property, Str, Undefined);
	
EndFunction

// Returns row presentation of the value type.
//
// Parameters: 
//  ValueOrType - custom value or value of the type type.
//
// Returns:
//  String - String presentation of the value type.
//
Function deValueTypeAsString(ValueOrType) Export

	ValueType	= TypeOf(ValueOrType);
	
	If ValueType = deTypeType Then
		ValueType	= ValueOrType;
	EndIf; 
	
	If (ValueType = Undefined) Or (ValueOrType = Undefined) Then
		Result = "";
	ElsIf ValueType = deStringType Then
		Result = "String";
	ElsIf ValueType = deNumberType Then
		Result = "Number";
	ElsIf ValueType = deDateType Then
		Result = "Date";
	ElsIf ValueType = deBooleanType Then
		Result = "Boolean";
	ElsIf ValueType = deValueStorageType Then
		Result = "ValueStorage";
	ElsIf ValueType = deUUIDType Then
		Result = "UUID";
	ElsIf ValueType = deAccumulationRecordTypeType Then
		Result = "AccumulationRecordType";
	Else
		Manager = Managers[ValueType];
		If Manager = Undefined Then
			
			Text= NStr("en='Unknown type:';ru='Незвестный тип:'") + String(TypeOf(ValueType));
			MessageToUser(Text);
			
		Else
			Result = Manager.RefTypeAsString;
		EndIf;
	EndIf;

	Return Result;
	
EndFunction

// Returns XML object presentation TypeDescription.
// Function can be used in the event handlers application code of which is stored in the data exchange rules.
// Parameters:
//  TypeDescription  - TypeDescription object, XML presentation of which should be received.
//
// Returns:
//  String - XML presentation of the TypeDescription passed object.
//
Function deGetXMLPresentationDescriptionTypes(TypeDescription) Export
	
	TypeNode = CreateNode("Types");
	
	If TypeOf(TypeDescription) = Type("Structure") Then
		SetAttribute(TypeNode, "AllowedSign",          TrimAll(TypeDescription.AllowedSign));
		SetAttribute(TypeNode, "Digits",             TrimAll(TypeDescription.Digits));
		SetAttribute(TypeNode, "FractionDigits", TrimAll(TypeDescription.FractionDigits));
		SetAttribute(TypeNode, "Length",                   TrimAll(TypeDescription.Length));
		SetAttribute(TypeNode, "AllowedLength",         TrimAll(TypeDescription.AllowedLength));
		SetAttribute(TypeNode, "DateContent",              TrimAll(TypeDescription.DateFractions));
		
		For Each StrType IN TypeDescription.Types Do
			TypeNode = CreateNode("Type");
			TypeNode.WriteText(TrimAll(StrType));
			AddSubordinate(TypeNode, TypeNode);
		EndDo;
	Else
		NumberQualifier       = TypeDescription.NumberQualifiers;
		StringQualifier      = TypeDescription.StringQualifiers;
		DateQualifier        = TypeDescription.DateQualifiers;
		
		SetAttribute(TypeNode, "AllowedSign",          TrimAll(NumberQualifier.AllowedSign));
		SetAttribute(TypeNode, "Digits",             TrimAll(NumberQualifier.Digits));
		SetAttribute(TypeNode, "FractionDigits", TrimAll(NumberQualifier.FractionDigits));
		SetAttribute(TypeNode, "Length",                   TrimAll(StringQualifier.Length));
		SetAttribute(TypeNode, "AllowedLength",         TrimAll(StringQualifier.AllowedLength));
		SetAttribute(TypeNode, "DateContent",              TrimAll(DateQualifier.DateFractions));
		
		For Each Type IN TypeDescription.Types() Do
			TypeNode = CreateNode("Type");
			TypeNode.WriteText(deValueTypeAsString(Type));
			AddSubordinate(TypeNode, TypeNode);
		EndDo;
	EndIf;
	
	TypeNode.WriteEndElement();
	
	Return(TypeNode.Close());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORK WITH OBJECT XMLWriter

// Replaces unavailable XML characters with another character.
//
// Parameters:
// Text - String
// ReplacementCharacter - String
//
Function ReplaceInadmissibleCharsXML(Val Text, ReplacementChar = " ") Export
	
	Position = FindDisallowedXMLCharacters(Text);
	While Position > 0 Do
		Text = StrReplace(Text, Mid(Text, Position, 1), ReplacementChar);
		Position = FindDisallowedXMLCharacters(Text);
	EndDo;
	
	Return Text;
EndFunction

Function DeleteInadmissibleCharsXML(Val Text)
	
	Return ReplaceInadmissibleCharsXML(Text, "");
	
EndFunction

// Creates
// new xml-node Function can be used in the events handlers
// application code of which is stored in the data exchange rules. Called using the Execute() method.
//
// Parameters: 
//  Name            - Node name
//
// Returns:
//  New xml-node object
//
Function CreateNode(Name) Export

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement(Name);

	Return XMLWriter;

EndFunction

// Adds a new xml node to the specified parent node.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters: 
//  ParentNode   - xml parent node.
//  Name            - added node name.
//
// Returns:
//  New xml node added to the specified parent node.
//
Function AddNode(ParentNode, Name) Export

	ParentNode.WriteStartElement(Name);

	Return ParentNode;

EndFunction

// Copies the specified xml-node.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. Called using the Execute() method.
// Message "Refs to the function are not found" while checking configuration is not a configuration checking error.
//
// Parameters: 
//  Node           - copied node.
//
// Returns:
//  New xml - specified node copy.
//
Function CopyNode(Node) Export

	Str = Node.Close();

	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	If KeepAdditionalWriteControlToXML Then
		
		Str = DeleteInadmissibleCharsXML(Str);
		
	EndIf;
	
	XMLWriter.WriteRaw(Str);

	Return XMLWriter;
	
EndFunction

// Records item and its value to the specified object.
//
// Parameters:
//  Object         - object of the XMLWriter type
//  Name            - String. Item name.
//  Value       - Item value.
// 
Procedure deWriteItem(Object, Name, Value="") Export

	Object.WriteStartElement(Name);
	Str = XMLString(Value);
	
	If KeepAdditionalWriteControlToXML Then
		
		Str = DeleteInadmissibleCharsXML(Str);
		
	EndIf;
	
	Object.WriteText(Str);
	Object.WriteEndElement();
	
EndProcedure

// Subjects an xml node to the specified parent node.
//
// Parameters: 
//  ParentNode   - xml parent node.
//  Node           - subordinate node.
//
Procedure AddSubordinate(ParentNode, Node) Export

	If TypeOf(Node) <> deStringType Then
		Node.WriteEndElement();
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	ParentNode.WriteRaw(InformationToWriteToFile);
		
EndProcedure

// Sets attribute of the specified xml-node.
//
// Parameters: 
//  Node           - xml-node
//  Name            - attribute name.
//  Value       - set value.
//
Procedure SetAttribute(Node, Name, Value) Export

	XMLString = XMLString(Value);
	
	If KeepAdditionalWriteControlToXML Then
		
		XMLString = DeleteInadmissibleCharsXML(XMLString);
		
	EndIf;
	
	Node.WriteAttribute(Name, XMLString);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORK WITH OBJECT XMLReading

// Reads attribute value by the name of the specified
// object, brings the value to the specified primitive type.
//
// Parameters:
//  Object      - XMLReading type object positioned on
//                the item start attribute of which is required to be received.
//  Type         - Value of the Type type. Attribute type.
//  Name         - String. Attribute name.
//
// Returns:
//  Attribute value received by the name and subjected to the specified type.
// 
Function deAttribute(Object, Type, Name) Export

	ValueStr = Object.GetAttribute(Name);
	If Not IsBlankString(ValueStr) Then
		Return XMLValue(Type, TrimR(ValueStr));
	ElsIf      Type = deStringType Then
		Return ""; 
	ElsIf Type = deBooleanType Then
		Return False;
	ElsIf Type = deNumberType Then
		Return 0;
	ElsIf Type = deDateType Then
		Return EmptyDateValue;
	EndIf;
		
EndFunction
 
// Skips xml nodes up to the end of the current item (current by default).
//
// Parameters:
//  Object   - object of the XMLReading type.
//  Name      - node name up to the end of which you should skip items.
// 
Procedure deIgnore(Object, Name = "") Export

	AttachmentsQuantity = 0; // Eponymous attachments quantity.

	If Name = "" Then
		
		Name = Object.LocalName;
		
	EndIf; 
	
	While Object.Read() Do
		
		If Object.LocalName <> Name Then
			Continue;
		EndIf;
		
		NodeType = Object.NodeType;
			
		If NodeType = odNodeTypeXML_EndElement Then
				
			If AttachmentsQuantity = 0 Then
					
				Break;
					
			Else
					
				AttachmentsQuantity = AttachmentsQuantity - 1;
					
			EndIf;
				
		ElsIf NodeType = odNodeTypeXML_StartElement Then
				
			AttachmentsQuantity = AttachmentsQuantity + 1;
				
		EndIf;
					
	EndDo;
	
EndProcedure

// Reads item text and reduces value to the specified type.
//
// Parameters:
//  Object           - object of the XMLReading type from which reading is executed.
//  Type              - received value type.
//  SearchByProperty - for reference types a property can be specified
//                     according to which you should search for an object: "Code", "Name", <AttributeName>, "Name" (predefined value).
//
// Returns:
//  Xml-item value reduced to the corresponding type.
//
Function deItemValue(Object, Type, SearchByProperty = "", CutStringRight = True) Export

	Value = "";
	Name      = Object.LocalName;

	While Object.Read() Do
		
		NodeType = Object.NodeType;
		
		If NodeType = odNodeTypeXML_Text Then
			
			Value = Object.Value;
			
			If CutStringRight Then
				
				Value = TrimR(Value);
				
			EndIf;
						
		ElsIf (Object.LocalName = Name) AND (NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		Else
			
			Return Undefined;
			
		EndIf;
		
	EndDo;

	
	If (Type = deStringType)
		OR (Type = deBooleanType)
		OR (Type = deNumberType)
		OR (Type = deDateType)
		OR (Type = deValueStorageType)
		OR (Type = deUUIDType)
		OR (Type = deAccumulationRecordTypeType)
		OR (Type = deAccountTypeType)
		Then
		
		Return XMLValue(Type, Value);
		
	Else
		
		Return deGetValueByString(Value, Type, SearchByProperty);
		
	EndIf;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH EXCHANGE FILE

// Saves specified xml-node to file.
//
// Parameters:
//  Node           - xml-node saved to file.
//
Procedure WriteToFile(Node) Export

	If TypeOf(Node) <> deStringType Then
		InformationToWriteToFile = Node.Close();
	Else
		InformationToWriteToFile = Node;
	EndIf;
	
	If DirectReadInRecipientInfobase Then
		
		ErrorStringInTargetInfobase = "";
		PassInformationAboutRecordsToReceiver(InformationToWriteToFile, ErrorStringInTargetInfobase);
		If Not IsBlankString(ErrorStringInTargetInfobase) Then
			
			Raise ErrorStringInTargetInfobase;
			
		EndIf;
		
	Else
		
		ExchangeFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
EndProcedure

// Opens exchange file, writes file title according to the exchange format.
//
// Parameters:
//  No.
//
Function OpenExportFile(ErrorMessageString = "")

	// Identify archive files according to the extension ".zip".
	
	If ArchiveFile Then
		ExchangeFileName = StrReplace(ExchangeFileName, ".zip", ".xml");
	EndIf;
    	
	ExchangeFile = New TextWriter;
	Try
		
		If DirectReadInRecipientInfobase Then
			ExchangeFile.Open(GetTempFileName(".xml"), TextEncoding.UTF8);
		Else
			ExchangeFile.Open(ExchangeFileName, TextEncoding.UTF8);
		EndIf;
				
	Except
		
		ErrorMessageString = WriteInExecutionProtocol(8);
		Return "";
		
	EndTry; 
	
	XMLInfoString = "<?xml version=""1.0"" encoding=""UTF-8""?>";
	
	ExchangeFile.WriteLine(XMLInfoString);

	TempXMLWriter = New XMLWriter();
	
	TempXMLWriter.SetString();
	
	TempXMLWriter.WriteStartElement("ExchangeFile");
							
	SetAttribute(TempXMLWriter, "FormatVersion", "2.0");
	SetAttribute(TempXMLWriter, "ExportDate",				CurrentSessionDate());
	SetAttribute(TempXMLWriter, "ExportPeriodStart",		StartDate);
	SetAttribute(TempXMLWriter, "ExportEndOfPeriod",	EndDate);
	SetAttribute(TempXMLWriter, "SourceConfigurationName",	Conversion.Source);
	SetAttribute(TempXMLWriter, "TargetConfigurationName",	Conversion.Receiver);
	SetAttribute(TempXMLWriter, "ConversionRuleIDs",		Conversion.ID);
	SetAttribute(TempXMLWriter, "Comment",				Comment);
	
	TempXMLWriter.WriteEndElement();
	
	Str = TempXMLWriter.Close(); 
	
	Str = StrReplace(Str, "/>", ">");
	
	ExchangeFile.WriteLine(Str);
	
	Return XMLInfoString + Chars.LF + Str;
			
EndFunction

// Closes exchange file
//
// Parameters:
//  No.
//
Procedure CloseFile()

    ExchangeFile.WriteLine("</ExchangeFile>");
	ExchangeFile.Close();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH EXCHANGE PROTOCOL

// Returns the structure type object containing
// all possible fields of the execution protocol record (error messages etc.).
//
// Parameters:
//  No.
//
// Returns:
//  Object of the structure type
// 
Function GetProtocolRecordStructure(MessageCode = "", ErrorString = "") Export

	ErrorStructure = New Structure("OCRName,DERName,NPP,Gnpp,Source,ObjectType,Property,Value,ValueType,OCR,PCR,PGCR,DDR,DCR,Object,TargetProperty,ConvertedValue,Handler,ErrorDescription,ModulePosition,Text,MessageCode,ExchangePlanNode");
	
	ModuleString              = SeparateBySeparator(ErrorString, "{");
	ErrorDescription            = SeparateBySeparator(ModuleString, "}: ");
	
	If ErrorDescription <> "" Then
		
		ErrorStructure.ErrorDescription         = ErrorDescription;
		ErrorStructure.ModulePosition          = ModuleString;
				
	EndIf;
	
	If ErrorStructure.MessageCode <> "" Then
		
		ErrorStructure.MessageCode           = MessageCode;
		
	EndIf;
	
	Return ErrorStructure;
	
EndFunction 

// Initializes file for writing events of the data import/export.
//
// Parameters:
//  No.
// 
Procedure ExchangeProtocolInitialization() Export
	
	If IsBlankString(ExchangeProtocolFileName) Then
		
		mDataLogFile = Undefined;
		CommentObjectProcessingFlag = InfoMessagesOutputToMessagesWindow;		
		Return;
		
	Else	
		
		CommentObjectProcessingFlag = OutputInInformationMessagesToProtocol OR InfoMessagesOutputToMessagesWindow;		
		
	EndIf;
	
	mDataLogFile = New TextWriter(ExchangeProtocolFileName, TextEncoding.ANSI, , AppendDataToExchangeProtocol) ;
	
EndProcedure

Procedure ExchangeProtocolInitializationForExportOfHandlers()
	
	// Receive unique attachment file name.
	TemporaryFileNameOfExchangeProtocol = GetNewUniqueNameOfTemporaryFile("ExchangeLog", "txt", TemporaryFileNameOfExchangeProtocol);
	
	mDataLogFile = New TextWriter(TemporaryFileNameOfExchangeProtocol, TextEncoding.ANSI);
	
	CommentObjectProcessingFlag = False;
	
EndProcedure

// Closes data exchange protocol file. File is saved to disc.
//
Procedure FinishExchangeProtocolLogging() Export 
	
	If mDataLogFile <> Undefined Then
		
		mDataLogFile.Close();
				
	EndIf;	
	
	mDataLogFile = Undefined;
	
EndProcedure

// Saves an execution protocol (or displays it) of the specified structure message.
//
// Parameters:
//  Code               - Number. Message code.
//  RecordStructure   - Structure. Structure of the protocol writing.
//  SetErrorFlag - If true, then - this error message. Display ErrorCheckBox.
// 
Function WriteInExecutionProtocol(Code="", RecordStructure=Undefined, SetErrorFlag=True, 
	Level=0, Align=22, ForceWritingToExchangeLog = False) Export

	Indent = "";
    For Ct = 0 To Level-1 Do
		Indent = Indent + Chars.Tab;
	EndDo; 
	
	If TypeOf(Code) = deNumberType Then
		
		If deMessages = Undefined Then
			MessagesInitialization();
		EndIf;
		
		Str = deMessages[Code];
		
	Else
		
		Str = String(Code);
		
	EndIf;

	Str = Indent + Str;
	
	If RecordStructure <> Undefined Then
		
		For Each Field IN RecordStructure Do
			
			Value = Field.Value;
			If Value = Undefined Then
				Continue;
			EndIf; 
			Key = Field.Key;
			Str  = Str + Chars.LF + Indent + Chars.Tab + deAddToString(Field.Key, Align) + " =  " + String(Value);
			
		EndDo;
		
	EndIf;
	
	ResultingStringToWrite = Chars.LF + Str;

	
	If SetErrorFlag Then
		
		SetFlagOfError(True);
		MessageToUser(ResultingStringToWrite);
		
	Else
		
		If DontOutputNoInformationMessagesToUser = False
			AND (ForceWritingToExchangeLog OR InfoMessagesOutputToMessagesWindow) Then
			
			MessageToUser(ResultingStringToWrite);
			
		EndIf;
		
	EndIf;
	
	If mDataLogFile <> Undefined Then
		
		If SetErrorFlag Then
			
			mDataLogFile.WriteLine(Chars.LF + "Error.");
			
		EndIf;
		
		If SetErrorFlag OR ForceWritingToExchangeLog OR OutputInInformationMessagesToProtocol Then
			
			mDataLogFile.WriteLine(ResultingStringToWrite);
		
		EndIf;		
		
	EndIf;
	
	Return Str;
		
EndFunction

// Writes error information to exchange execution protocol.
//
Function WriteInformationAboutErrorToProtocol(MessageCode, ErrorString, Object, ObjectType = Undefined) Export
	
	LR         = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.Object  = Object;
	
	If ObjectType <> Undefined Then
		LR.ObjectType     = ObjectType;
	EndIf;	
		
	ErrorString = WriteInExecutionProtocol(MessageCode, LR);	
	
	Return ErrorString;	
	
EndFunction

// Writes error information to exchange execution protocol for data clearing handler.
//
Function WriteInformationAboutDataClearHandlerError(MessageCode, ErrorString, DataClearingRuleName, Object = "", HandlerName = "")Export
	
	LR                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.DCR                    = DataClearingRuleName;
	
	If Object <> "" Then
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			LR.Object = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			LR.Object = "" + TypeOf(Object) + "";
		EndIf;
	EndIf;
	
	If HandlerName <> "" Then
		LR.Handler             = HandlerName;
	EndIf;
	
	ErrorMessageString = WriteInExecutionProtocol(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;	
	
EndFunction

// Registers ORC handler error in the execution protocol (import).
//
Function WriteInformationAboutOCRHandlerErrorImport(MessageCode, ErrorString, Rulename, Source,
	ObjectType, Object, HandlerName) Export
	
	LR            = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.OCRName     = Rulename;
	LR.ObjectType = ObjectType;
	LR.Handler = HandlerName;
	
	If Not IsBlankString(Source) Then
		
		LR.Source = Source;
		
	EndIf;
	
	If Object <> Undefined Then
		
		LR.Object = String(Object);
		
	EndIf;
	
	ErrorMessageString = WriteInExecutionProtocol(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
	
EndFunction

// Registers ORC handler error in the execution protocol (export).
//
Function WriteInformationAboutOCRHandlerErrorDump(MessageCode, ErrorString, OCR, Source, HandlerName)
	
	LR                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	TypeDescription = New TypeDescription("String");
	SourceRow  = TypeDescription.AdjustValue(Source);
	If Not IsBlankString(SourceRow) Then
		LR.Object = SourceRow + "  (" + TypeOf(Source) + ")";
	Else
		LR.Object = "(" + TypeOf(Source) + ")";
	EndIf;
	
	LR.Handler = HandlerName;
	
	ErrorMessageString = WriteInExecutionProtocol(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndFunction

// Registers PCR handler error in the execution protocol.
//
Function WriteInformationAboutErrorPCRHandlers(MessageCode, ErrorString, OCR, PCR, Source = "", 
	HandlerName = "", Value = Undefined, ItIsPCR = True) Export
	
	LR                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.OCR                    = OCR.Name + "  (" + OCR.Description + ")";
	
	Rulename = PCR.Name + "  (" + PCR.Description + ")";
	If ItIsPCR Then
		LR.PCR                = Rulename;
	Else
		LR.PGCR               = Rulename;
	EndIf;
	
	TypeDescription = New TypeDescription("String");
	SourceRow  = TypeDescription.AdjustValue(Source);
	If Not IsBlankString(SourceRow) Then
		LR.Object = SourceRow + "  (" + TypeOf(Source) + ")";
	Else
		LR.Object = "(" + TypeOf(Source) + ")";
	EndIf;
	
	If ItIsPCR Then
		LR.TargetProperty      = PCR.Receiver + "  (" + PCR.ReceiverType + ")";
	EndIf;
	
	If HandlerName <> "" Then
		LR.Handler         = HandlerName;
	EndIf;
	
	If Value <> Undefined Then
		LR.ConvertedValue = String(Value) + "  (" + TypeOf(Value) + ")";
	EndIf;
	
	ErrorMessageString = WriteInExecutionProtocol(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
		
EndFunction	

Function WriteInformationAboutErrorDDRHandlers(MessageCode, ErrorString, Rulename, HandlerName, Object = Undefined)
	
	LR                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.DDR                    = Rulename;
	
	If Object <> Undefined Then
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			LR.Object = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			LR.Object = "" + TypeOf(Object) + "";
		EndIf;
	EndIf;
	
	LR.Handler             = HandlerName;
	
	ErrorMessageString = WriteInExecutionProtocol(MessageCode, LR);
	
	If Not DebugModeFlag Then
		Raise ErrorMessageString;
	EndIf;
	
EndFunction

Function WriteInformationAboutErrorConversionHandlers(MessageCode, ErrorString, HandlerName)
	
	LR                        = GetProtocolRecordStructure(MessageCode, ErrorString);
	LR.Handler             = HandlerName;
	ErrorMessageString = WriteInExecutionProtocol(MessageCode, LR);
	Return ErrorMessageString;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// EXCHANGE RULES UPLOAD PROCEDURES

// Imports conversion rule of properties group.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  PropertyTable - values table containing PCR.
// 
Procedure ImportPGCR(ExchangeRules, PropertyTable)

	If deAttribute(ExchangeRules, deBooleanType, "Disable") Then
		deIgnore(ExchangeRules);
		Return;
	EndIf;

	
	NewRow               = PropertyTable.Add();
	NewRow.IsFolder     = True;
	NewRow.GroupRules = mPropertyConversionRuleTable.Copy();

	
	// Default values

	NewRow.Donotreplace               = False;
	NewRow.GetFromIncomingData = False;
	NewRow.SimplifiedPropertyExport = False;
	
	SearchFieldString = "";	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, deStringType, "Type");
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Receiver" Then
			NewRow.Receiver		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.TargetKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.ReceiverType	= deAttribute(ExchangeRules, deStringType, "Type");
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Property" Then
			ImportPCR(ExchangeRules, NewRow.GroupRules, , SearchFieldString);

		ElsIf NodeName = "BeforeProcessExport" Then
			NewRow.BeforeProcessExport	= GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasBeforeProcessExportHandler = Not IsBlankString(NewRow.BeforeProcessExport);
			
		ElsIf NodeName = "AfterProcessExport" Then
			NewRow.AfterProcessExport	= GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasAfterProcessExportHandler = Not IsBlankString(NewRow.AfterProcessExport);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Donotreplace" Then
			NewRow.Donotreplace = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetFromTextHandlerValue(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "ExportGroupToFile" Then
			NewRow.ExportGroupToFile = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Group") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SearchFieldString = SearchFieldString;
	
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler OR NewRow.HasAfterExportHandler;
	
	NewRow.XMLNodeRequiredOnExportGroup = NewRow.HasAfterProcessExportHandler; 

EndProcedure

Procedure AddFieldToSearchString(SearchFieldString, FieldName)
	
	If IsBlankString(FieldName) Then
		Return;
	EndIf;
	
	If Not IsBlankString(SearchFieldString) Then
		SearchFieldString = SearchFieldString + ",";
	EndIf;
	
	SearchFieldString = SearchFieldString + FieldName;
	
EndProcedure

// Imports properties conversion rule.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  PropertyTable - values table containing PCR.
//  SearchTable  - values table containing PCR (synchronizing).
// 
Procedure ImportPCR(ExchangeRules, PropertyTable, SearchTable = Undefined, SearchFieldString = "")

	If deAttribute(ExchangeRules, deBooleanType, "Disable") Then
		deIgnore(ExchangeRules);
		Return;
	EndIf;

	
	IsSearchField = deAttribute(ExchangeRules, deBooleanType, "Search");
	
	If IsSearchField 
		AND SearchTable <> Undefined Then
		
		NewRow = SearchTable.Add();
		
	Else
		
		NewRow = PropertyTable.Add();
		
	EndIf;  

	
	// Default values

	NewRow.Donotreplace               = False;
	NewRow.GetFromIncomingData = False;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" Then
			NewRow.Source		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.SourceKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.SourceType	= deAttribute(ExchangeRules, deStringType, "Type");
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Receiver" Then
			NewRow.Receiver		= deAttribute(ExchangeRules, deStringType, "Name");
			NewRow.TargetKind	= deAttribute(ExchangeRules, deStringType, "Kind");
			NewRow.ReceiverType	= deAttribute(ExchangeRules, deStringType, "Type");
			
			If IsSearchField Then
				AddFieldToSearchString(SearchFieldString, NewRow.Receiver);
			EndIf;
			
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Donotreplace" Then
			NewRow.Donotreplace = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "BeforeExport" Then
			NewRow.BeforeExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			NewRow.OnExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			NewRow.AfterExport = GetFromTextHandlerValue(ExchangeRules);
	        NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "GetFromIncomingData" Then
			NewRow.GetFromIncomingData = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "CastToLength" Then
			NewRow.CastToLength = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "ParameterForTransferName" Then
			NewRow.ParameterForTransferName = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SearchByEqualDate" Then
			NewRow.SearchByEqualDate = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf (NodeName = "Property") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
	NewRow.SimplifiedPropertyExport = Not NewRow.GetFromIncomingData
		AND Not NewRow.HasBeforeExportHandler
		AND Not NewRow.HasOnExportHandler
		AND Not NewRow.HasAfterExportHandler
		AND IsBlankString(NewRow.ConversionRule)
		AND NewRow.SourceType = NewRow.ReceiverType
		AND (NewRow.SourceType = "String" OR NewRow.SourceType = "Number" OR NewRow.SourceType = "Boolean" OR NewRow.SourceType = "Date");
		
	NewRow.XMLNodeRequiredOnExport = NewRow.HasOnExportHandler OR NewRow.HasAfterExportHandler;
	
EndProcedure

// Imports properties conversion rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  PropertyTable - values table containing PCR.
//  SearchTable  - values table containing PCR (synchronizing).
// 
Procedure ImportProperties(ExchangeRules, PropertyTable, SearchTable)

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Property" Then
			ImportPCR(ExchangeRules, PropertyTable, SearchTable);
		ElsIf NodeName = "Group" Then
			ImportPGCR(ExchangeRules, PropertyTable);
		ElsIf (NodeName = "Properties") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	PropertyTable.Sort("Order");
	SearchTable.Sort("Order");
	
EndProcedure

// Imports values conversion rule.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  Values       - match of the source object values - String
//                   presentation of the receiver object.
//  SourceType   - value of the Type type - source object type.
// 
Procedure ImportVCR(ExchangeRules, Values, SourceType)

	Source = "";
	Receiver = "";
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Source" Then
			Source = deItemValue(ExchangeRules, deStringType);
		ElsIf NodeName = "Receiver" Then
			Receiver = deItemValue(ExchangeRules, deStringType);
		ElsIf (NodeName = "Value") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	Values[deGetValueByString(Source, SourceType)] = Receiver;
	
EndProcedure

// Imports value conversion rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  Values       - match of the source object values - String
//                   presentation of the receiver object.
//  SourceType   - value of the Type type - source object type.
// 
Procedure LoadValues(ExchangeRules, Values, SourceType);

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Value" Then
			ImportVCR(ExchangeRules, Values, SourceType);
		ElsIf (NodeName = "Values") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;
	
EndProcedure

// OCR clearing procedure in managers for exchange rules.
Procedure ClearOCROfManagers()
	
	If Managers = Undefined Then
		Return;
	EndIf;
	
	For Each RuleManager IN Managers Do
		RuleManager.Value.OCR = Undefined;
	EndDo;
	
EndProcedure

// Imports objects conversion rule.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportConversionRule(ExchangeRules, XMLWriter)

	XMLWriter.WriteStartElement("Rule");

	NewRow = ConversionRulesTable.Add();

	
	// Default values
	
	NewRow.RememberExported = True;
	NewRow.Donotreplace            = False;
	
	
	SearchInTSTable = New ValueTable;
	SearchInTSTable.Columns.Add("ItemName");
	SearchInTSTable.Columns.Add("TSSearchFields");
	
	NewRow.SearchInTabularSections = SearchInTSTable;
	
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
				
		If      NodeName = "Code" Then
			
			Value = deItemValue(ExchangeRules, deStringType);
			deWriteItem(XMLWriter, NodeName, Value);
			NewRow.Name = Value;
			
		ElsIf NodeName = "Description" Then
			
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SynchronizeByID" Then
			
			NewRow.SynchronizeByID = deItemValue(ExchangeRules, deBooleanType);
			deWriteItem(XMLWriter, NodeName, NewRow.SynchronizeByID);
			
		ElsIf NodeName = "DoNotCreateIfNotFound" Then
			
			NewRow.DoNotCreateIfNotFound = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DontExportPropertyObjectsByRefs" Then
			
			NewRow.DontExportPropertyObjectsByRefs = deItemValue(ExchangeRules, deBooleanType);
						
		ElsIf NodeName = "SearchBySearchFieldsIfNotFoundByID" Then
			
			NewRow.SearchBySearchFieldsIfNotFoundByID = deItemValue(ExchangeRules, deBooleanType);	
			deWriteItem(XMLWriter, NodeName, NewRow.SearchBySearchFieldsIfNotFoundByID);
			
		ElsIf NodeName = "OnExchangeObjectByRefSetGIUDOnly" Then
			
			NewRow.OnExchangeObjectByRefSetGIUDOnly = deItemValue(ExchangeRules, deBooleanType);	
			deWriteItem(XMLWriter, NodeName, NewRow.OnExchangeObjectByRefSetGIUDOnly);
			
		ElsIf NodeName = "DontReplaceCreatedInTargetObject" Then
			// it does not influence exchange
			DontReplaceCreatedInTargetObject = deItemValue(ExchangeRules, deBooleanType);	
						
		ElsIf NodeName = "UseQuickSearchOnImport" Then
			
			NewRow.UseQuickSearchOnImport = deItemValue(ExchangeRules, deBooleanType);	
			
		ElsIf NodeName = "Generatenewnumberorcodeifnotspecified" Then
			
			NewRow.Generatenewnumberorcodeifnotspecified = deItemValue(ExchangeRules, deBooleanType);
			deWriteItem(XMLWriter, NodeName, NewRow.Generatenewnumberorcodeifnotspecified);
			
		ElsIf NodeName = "DontRememberExported" Then
			
			NewRow.RememberExported = Not deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "Donotreplace" Then
			
			Value = deItemValue(ExchangeRules, deBooleanType);
			deWriteItem(XMLWriter, NodeName, Value);
			NewRow.Donotreplace = Value;
			
		ElsIf NodeName = "ExchangeObjectPriority" Then
			
			// It does not participate in a universal exchange.
			ExchangeObjectPriority = deItemValue(ExchangeRules, deStringType);			
			
		ElsIf NodeName = "Receiver" Then
			
			Value = deItemValue(ExchangeRules, deStringType);
			deWriteItem(XMLWriter, NodeName, Value);
			NewRow.Receiver = Value;
			
		ElsIf NodeName = "Source" Then
			
			Value = deItemValue(ExchangeRules, deStringType);
			deWriteItem(XMLWriter, NodeName, Value);
			
			If ExchangeMode = "Import" Then
				
				NewRow.Source	= Value;
				
			Else
				
				If Not IsBlankString(Value) Then
					          
					NewRow.SourceType = Value;
					NewRow.Source	= Type(Value);
					
					Try
						
						Managers[NewRow.Source].OCR = NewRow;
						
					Except
						
						WriteInformationAboutErrorToProtocol(11, ErrorDescription(), String(NewRow.Source));
						
					EndTry; 
					
				EndIf;
				
			EndIf;
			
		// Properties
		
		ElsIf NodeName = "Properties" Then
		
			NewRow.SearchProperties	= mPropertyConversionRuleTable.Copy();
			NewRow.Properties		= mPropertyConversionRuleTable.Copy();
			
			
			If NewRow.SynchronizeByID <> Undefined AND NewRow.SynchronizeByID Then
				
				SearchPropertyUUID = NewRow.SearchProperties.Add();
				SearchPropertyUUID.Name = "{UUID}";
				SearchPropertyUUID.Source = "{UUID}";
				SearchPropertyUUID.Receiver = "{UUID}";
				
			EndIf;
			
			ImportProperties(ExchangeRules, NewRow.Properties, NewRow.SearchProperties);

			
		// Values
		
		ElsIf NodeName = "Values" Then
		
			LoadValues(ExchangeRules, NewRow.Values, NewRow.Source);

			
		// EVENT HANDLERS
		
		ElsIf NodeName = "BeforeExport" Then
		
			NewRow.BeforeExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasBeforeExportHandler = Not IsBlankString(NewRow.BeforeExport);
			
		ElsIf NodeName = "OnExport" Then
			
			NewRow.OnExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasOnExportHandler    = Not IsBlankString(NewRow.OnExport);
			
		ElsIf NodeName = "AfterExport" Then
			
			NewRow.AfterExport = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasAfterExportHandler  = Not IsBlankString(NewRow.AfterExport);
			
		ElsIf NodeName = "AfterExportToFile" Then
			
			NewRow.AfterExportToFile = GetFromTextHandlerValue(ExchangeRules);
			NewRow.HasAfterExportToFileHandler  = Not IsBlankString(NewRow.AfterExportToFile);
						
		// For import
		
		ElsIf NodeName = "BeforeImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			
 			If ExchangeMode = "Import" Then
				
				NewRow.BeforeImport               = Value;
				NewRow.HasBeforeImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "OnImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				NewRow.OnImport               = Value;
				NewRow.HasOnImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf; 
			
		ElsIf NodeName = "AfterImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				NewRow.AfterImport               = Value;
				NewRow.HasAfterImportHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
	 		EndIf;
			
		ElsIf NodeName = "SearchFieldSequence" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			NewRow.HasSearchFieldSequenceHandler = Not IsBlankString(Value);
			
			If ExchangeMode = "Import" Then
				
				NewRow.SearchFieldSequence = Value;
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "SearchInTabularSections" Then
			
			Value = deItemValue(ExchangeRules, deStringType);
			
			For Number = 1 To StrLineCount(Value) Do
				
				CurrentRow = StrGetLine(Value, Number);
				
				SearchString = SeparateBySeparator(CurrentRow, ":");
				
				TableRow = SearchInTSTable.Add();
				TableRow.ItemName = CurrentRow;
				
				TableRow.TSSearchFields = DecomposeStringIntoSubstringsArray(SearchString);
				
			EndDo;
			
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;
	
	ResultingTSSearchString = "";
	
	// Pass information about search fields for the tabular sections to the receiver.
	For Each PropertiesString IN NewRow.Properties Do
		
		If Not PropertiesString.IsFolder
			OR IsBlankString(PropertiesString.SourceKind)
			OR IsBlankString(PropertiesString.Receiver) Then
			
			Continue;
			
		EndIf;
		
		If IsBlankString(PropertiesString.SearchFieldString) Then
			Continue;
		EndIf;
		
		ResultingTSSearchString = ResultingTSSearchString + Chars.LF + PropertiesString.SourceKind + "." + PropertiesString.Receiver + ":" + PropertiesString.SearchFieldString;
		
	EndDo;
	
	ResultingTSSearchString = TrimAll(ResultingTSSearchString);
	
	If Not IsBlankString(ResultingTSSearchString) Then
		
		deWriteItem(XMLWriter, "SearchInTabularSections", ResultingTSSearchString);	
		
	EndIf;

	XMLWriter.WriteEndElement();

	
	// Quick access to OCR by name.
	
	Rules.Insert(NewRow.Name, NewRow);
	
EndProcedure
 
// Imports objects conversion rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportConversionRules(ExchangeRules, XMLWriter)

	ConversionRulesTable.Clear();
	ClearOCROfManagers();
	
	XMLWriter.WriteStartElement("ObjectConversionRules");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Rule" Then
			
			ImportConversionRule(ExchangeRules, XMLWriter);
			
		ElsIf (NodeName = "ObjectConversionRules") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports data clearing rules group according to the exchange rules format.
//
// Parameters:
//  NewRow    - values tree string describing data clearing rules group.
// 
Procedure ImportGroupDCR(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(NOT deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		
		If      NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDCR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") AND (NodeType = odNodeTypeXML_StartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportGroupDCR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") AND (NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules according to the exchange rules format.
//
// Parameters:
//  NewRow    - values tree string describing data clearing rules.
// 
Procedure ImportDCR(ExchangeRules, NewRow)
	
	NewRow.Enable = Number(NOT deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Code" Then
			Value = deItemValue(ExchangeRules, deStringType);
			NewRow.Name = Value;

		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			NewRow.DataSelectionVariant = deItemValue(ExchangeRules, deStringType);

		ElsIf NodeName = "SelectionObject" Then
			SelectionObject = deItemValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject) Then
				NewRow.SelectionObject = Type(SelectionObject);
			EndIf; 

		ElsIf NodeName = "DeleteForPeriod" Then
			NewRow.DeleteForPeriod = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "Directly" Then
			NewRow.Directly = deItemValue(ExchangeRules, deBooleanType);

		
		// EVENT HANDLERS

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetFromTextHandlerValue(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcessing = GetFromTextHandlerValue(ExchangeRules);
		
		ElsIf NodeName = "BeforeDeleteObject" Then
			NewRow.BeforeDelete = GetFromTextHandlerValue(ExchangeRules);

		// Exit
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
			
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data clearing rules.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportClearRules(ExchangeRules, XMLWriter)
	
 	FlushRulesTable.Rows.Clear();
	VTRows = FlushRulesTable.Rows;
	
	XMLWriter.WriteStartElement("DataClearingRules");

	While ExchangeRules.Read() Do
		
		NodeType = ExchangeRules.NodeType;
		
		If NodeType = odNodeTypeXML_StartElement Then
			NodeName = ExchangeRules.LocalName;
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteStartElement(ExchangeRules.Name);
				While ExchangeRules.ReadAttribute() Do
					XMLWriter.WriteAttribute(ExchangeRules.Name, ExchangeRules.Value);
				EndDo;
			Else
				If NodeName = "Rule" Then
					VTRow = VTRows.Add();
					ImportDCR(ExchangeRules, VTRow);
				ElsIf NodeName = "Group" Then
					VTRow = VTRows.Add();
					ImportGroupDCR(ExchangeRules, VTRow);
				EndIf;
			EndIf;
		ElsIf NodeType = odNodeTypeXML_EndElement Then
			NodeName = ExchangeRules.LocalName;
			If NodeName = "DataClearingRules" Then
				Break;
			Else
				If ExchangeMode <> "Import" Then
					XMLWriter.WriteEndElement();
				EndIf;
			EndIf;
		ElsIf NodeType = odNodeTypeXML_Text Then
			If ExchangeMode <> "Import" Then
				XMLWriter.WriteText(ExchangeRules.Value);
			EndIf;
		EndIf; 
	EndDo;

	VTRows.Sort("Order", True);
	
 	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports algorithm according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportAlgorithm(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = GetFromTextHandlerValue(ExchangeRules);
		ElsIf (NodeName = "Algorithm") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		Else
			deIgnore(ExchangeRules);
		EndIf;
		
	EndDo;

	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Algorithms.Insert(Name, Text);
		Else
			XMLWriter.WriteStartElement("Algorithm");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteItem(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Algorithms.Insert(Name, Text);
		EndIf;
	EndIf;
	
	
EndProcedure

// Imports algorithms according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportAlgorithms(ExchangeRules, XMLWriter)

	Algorithms.Clear();

	XMLWriter.WriteStartElement("Algorithms");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Algorithm" Then
			ImportAlgorithm(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Algorithms") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports query according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportQuery(ExchangeRules, XMLWriter)

	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Text" Then
			Text = GetFromTextHandlerValue(ExchangeRules);
		ElsIf (NodeName = "Query") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		Else
			deIgnore(ExchangeRules);
		EndIf;
		
	EndDo;

	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		Else
			XMLWriter.WriteStartElement("Query");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",   Name);
			deWriteItem(XMLWriter, "Text", Text);
			XMLWriter.WriteEndElement();
		EndIf;
	Else
		If ExchangeMode <> "Import" Then
			Query	= New Query(Text);
			Queries.Insert(Name, Query);
		EndIf;
	EndIf;
	
EndProcedure

// Imports queries according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportQueries(ExchangeRules, XMLWriter)

	Queries.Clear();

	XMLWriter.WriteStartElement("Queries");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "Query" Then
			ImportQuery(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "Queries") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports parameters according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
// 
Procedure ImportParameters(ExchangeRules, XMLWriter)

	Parameters.Clear();
	EventsAfterParameterImport.Clear();
	ParametersSettingsTable.Clear();
	
	XMLWriter.WriteStartElement("Parameters");
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;

		If NodeName = "Parameter" AND NodeType = odNodeTypeXML_StartElement Then
			
			// Import by rules version 2.01.
			Name                     = deAttribute(ExchangeRules, deStringType, "Name");
			Description            = deAttribute(ExchangeRules, deStringType, "Description");
			SetInDialog   = deAttribute(ExchangeRules, deBooleanType, "SetInDialog");
			ValueTypeString      = deAttribute(ExchangeRules, deStringType, "ValueType");
			UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");
			PassParameterOnExport = deAttribute(ExchangeRules, deBooleanType, "PassParameterOnExport");
			ConversionRule = deAttribute(ExchangeRules, deStringType, "ConversionRule");
			AfterParameterImportAlgorithm = deAttribute(ExchangeRules, deStringType, "AfterParameterImport");
			
			If Not IsBlankString(AfterParameterImportAlgorithm) Then
				
				EventsAfterParameterImport.Insert(Name, AfterParameterImportAlgorithm);
				
			EndIf;
			
			// Determine value types and set initial values.
			If Not IsBlankString(ValueTypeString) Then
				
				Try
					DataValueType = Type(ValueTypeString);
					TypeDefined = TRUE;
				Except
					TypeDefined = FALSE;
				EndTry;
				
			Else
				
				TypeDefined = FALSE;
				
			EndIf;
			
			If TypeDefined Then
				ParameterValue = deGetBlankValue(DataValueType);
				Parameters.Insert(Name, ParameterValue);
			Else
				ParameterValue = "";
				Parameters.Insert(Name);
			EndIf;
						
			If SetInDialog = TRUE Then
				
				TableRow              = ParametersSettingsTable.Add();
				TableRow.Description = Description;
				TableRow.Name          = Name;
				TableRow.Value = ParameterValue;				
				TableRow.PassParameterOnExport = PassParameterOnExport;
				TableRow.ConversionRule = ConversionRule;
				
			EndIf;
			
			If UsedOnImport
				AND ExchangeMode = "Export" Then
				
				XMLWriter.WriteStartElement("Parameter");
				SetAttribute(XMLWriter, "Name",   Name);
				SetAttribute(XMLWriter, "Description", Description);
					
				If Not IsBlankString(AfterParameterImportAlgorithm) Then
					SetAttribute(XMLWriter, "AfterParameterImport", XMLString(AfterParameterImportAlgorithm));
				EndIf;
				
				XMLWriter.WriteEndElement();
				
			EndIf;

		ElsIf (NodeType = odNodeTypeXML_Text) Then
			
			// For compatibility with rules version 2.0 use import from string.
			ParameterString = ExchangeRules.Value;
			For Each Param IN ArrayFromString(ParameterString) Do
				Parameters.Insert(Param);
			EndDo;
			
		ElsIf (NodeName = "Parameters") AND (NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();

EndProcedure

// Imports data processor according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportDataProcessor(ExchangeRules, XMLWriter)

	Name                     = deAttribute(ExchangeRules, deStringType, "Name");
	Description            = deAttribute(ExchangeRules, deStringType, "Description");
	IsSetupDataProcessor   = deAttribute(ExchangeRules, deBooleanType, "IsSetupDataProcessor");
	
	UsedOnExport = deAttribute(ExchangeRules, deBooleanType, "UsedOnExport");
	UsedOnImport = deAttribute(ExchangeRules, deBooleanType, "UsedOnImport");

	ParameterString        = deAttribute(ExchangeRules, deStringType, "Parameters");
	
	DataProcessorStorage      = deItemValue(ExchangeRules, deValueStorageType);

	AdditionalInformationProcessorParameters.Insert(Name, ArrayFromString(ParameterString));
	
	
	If UsedOnImport Then
		If ExchangeMode = "Import" Then
			
		Else
			XMLWriter.WriteStartElement("DataProcessor");
			SetAttribute(XMLWriter, "UsedOnImport", True);
			SetAttribute(XMLWriter, "Name",                     Name);
			SetAttribute(XMLWriter, "Description",            Description);
			SetAttribute(XMLWriter, "IsSetupDataProcessor",   IsSetupDataProcessor);
			XMLWriter.WriteText(XMLString(DataProcessorStorage));
			XMLWriter.WriteEndElement();
		EndIf;
	EndIf;
	
	If IsSetupDataProcessor Then
		If (ExchangeMode = "Import") AND UsedOnImport Then
			ImportConfigurationProcedures.Add(Name, Description, , );
			
		ElsIf (ExchangeMode = "Export") AND UsedOnExport Then
			DumpConfigurationProcedures.Add(Name, Description, , );
			
		EndIf; 
	EndIf; 
	
EndProcedure

// Imports external data processors according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  XMLWriter      - Object of the XMLWriter type - rules saved to the exchange
//                   file and used while importing data.
// 
Procedure ImportDataProcessors(ExchangeRules, XMLWriter)

	AdditionalInformationProcessors.Clear();
	AdditionalInformationProcessorParameters.Clear();
	
	DumpConfigurationProcedures.Clear();
	ImportConfigurationProcedures.Clear();

	XMLWriter.WriteStartElement("DataProcessors");
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If      NodeName = "DataProcessor" Then
			ImportDataProcessor(ExchangeRules, XMLWriter);
		ElsIf (NodeName = "DataProcessors") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	XMLWriter.WriteEndElement();
	
EndProcedure

// Imports data export rules group according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  NewRow    - values tree string describing data export rules group.
// 
Procedure ImportDDRGroup(ExchangeRules, NewRow)

	NewRow.IsFolder = True;
	NewRow.Enable  = Number(NOT deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		NodeType = ExchangeRules.NodeType;
		If      NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "Rule" Then
			VTRow = NewRow.Rows.Add();
			ImportDDR(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "Group") AND (NodeType = odNodeTypeXML_StartElement) Then
			VTRow = NewRow.Rows.Add();
			ImportDDRGroup(ExchangeRules, VTRow);
					
		ElsIf (NodeName = "Group") AND (NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	
	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data export rule according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
//  NewRow    - values tree string describing data export rules.
// 
Procedure ImportDDR(ExchangeRules, NewRow)

	NewRow.Enable = Number(NOT deAttribute(ExchangeRules, deBooleanType, "Disable"));
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		If      NodeName = "Code" Then
			NewRow.Name = deItemValue(ExchangeRules, deStringType);

		ElsIf NodeName = "Description" Then
			NewRow.Description = deItemValue(ExchangeRules, deStringType);
		
		ElsIf NodeName = "Order" Then
			NewRow.Order = deItemValue(ExchangeRules, deNumberType);
			
		ElsIf NodeName = "DataSelectionVariant" Then
			NewRow.DataSelectionVariant = deItemValue(ExchangeRules, deStringType);
			
		ElsIf NodeName = "SelectExportDataInSingleQuery" Then
			NewRow.SelectExportDataInSingleQuery = deItemValue(ExchangeRules, deBooleanType);
			
		ElsIf NodeName = "DontExportCreatedInTargetInfobaseObjects" Then
			// Parameter is ignored while data exchange.
			DontExportCreatedInTargetInfobaseObjects = deItemValue(ExchangeRules, deBooleanType);

		ElsIf NodeName = "SelectionObject" Then
			SelectionObject = deItemValue(ExchangeRules, deStringType);
			If Not IsBlankString(SelectionObject) Then
				NewRow.SelectionObject = Type(SelectionObject);
			EndIf;
			// To support filter using builder.
			If Find(SelectionObject, "Ref.") Then
				NewRow.ObjectForQueryName = StrReplace(SelectionObject, "Ref.", ".");
			Else
				NewRow.ObjectNameForRegisterQuery = StrReplace(SelectionObject, "Record.", ".");
			EndIf;

		ElsIf NodeName = "ConversionRuleCode" Then
			NewRow.ConversionRule = deItemValue(ExchangeRules, deStringType);

		// EVENT HANDLERS

		ElsIf NodeName = "BeforeProcessRule" Then
			NewRow.BeforeProcess = GetFromTextHandlerValue(ExchangeRules);
			
		ElsIf NodeName = "AfterProcessRule" Then
			NewRow.AfterProcessing = GetFromTextHandlerValue(ExchangeRules);
		
		ElsIf NodeName = "BeforeObjectExport" Then
			NewRow.BeforeExport = GetFromTextHandlerValue(ExchangeRules);

		ElsIf NodeName = "AfterObjectExport" Then
			NewRow.AfterExport = GetFromTextHandlerValue(ExchangeRules);
        		
		ElsIf (NodeName = "Rule") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		EndIf;
		
	EndDo;

	If IsBlankString(NewRow.Description) Then
		NewRow.Description = NewRow.Name;
	EndIf; 
	
EndProcedure

// Imports data export rules according to the exchange rules format.
//
// Parameters:
//  ExchangeRules  - Object of the XMLReading type.
// 
Procedure ImportDumpRules(ExchangeRules)

	UnloadRulesTable.Rows.Clear();

	VTRows = UnloadRulesTable.Rows;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Rule" Then
			
			VTRow = VTRows.Add();
			ImportDDR(ExchangeRules, VTRow);
			
		ElsIf NodeName = "Group" Then
			
			VTRow = VTRows.Add();
			ImportDDRGroup(ExchangeRules, VTRow);
			
		ElsIf (NodeName = "DataUnloadRules") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;

	VTRows.Sort("Order", True);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF HANDLERS AND ALGORITHMS EXPORT TO TXT-FILE FROM EXCHANGE RULES

// Exports event handlers and algorithms to the temporary text file (to the user temporary directory).
// Generates debugging module with handlers and algorithms and all required global variables, general functions wrappers and comments.
//
// Parameters:
//  Cancel - check box of debugging module creation denial. Appears
//          if you were unable to read exchange rules.
//
Procedure ExportEventHandlers(Cancel) Export
	
	ExchangeProtocolInitializationForExportOfHandlers();
	
	DataProcessingMode = mDataProcessingModes.EventHandlerExport;
	
	ErrorFlag = False;
	
	ImportExchangeRulesForExportOfHandlers();
	
	If ErrorFlag Then
		Cancel = True;
		Return;
	EndIf; 
	
	SupplementRulesWithInterfacesOfHandlers(Conversion, ConversionRulesTable, UnloadRulesTable, FlushRulesTable);
	
	If AlgorithmsDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		GetFullCodeOfAlgorithmsWithHierarchy();
		
	EndIf;
	
	// Receive unique attachment file name.
	TemporaryFileNameOfEventHandlers = GetNewUniqueNameOfTemporaryFile("EventsHandlers", "txt", TemporaryFileNameOfEventHandlers);
	
	Result = New TextWriter(TemporaryFileNameOfEventHandlers, TextEncoding.ANSI);
	
	mCommonProcedureFunctionsTemplate = GetTemplate("CommonProcedureFunctions");
	
	// Output comments.
	AddInStreamComment(Result, "Header");
	AddInStreamComment(Result, "DataProcessorVariables");
	
	// Output service code.
	AddInStreamServiceCode(Result, "DataProcessorVariables");
	
	// Export global processors.
	ExportConversionHandlers(Result);
	
	// Exporting DDR.
	AddInStreamComment(Result, "DDR", UnloadRulesTable.Rows.Count() <> 0);
	ExportDumpRulesHandlers(Result, UnloadRulesTable.Rows);
	
	// Exporting DCR.
	AddInStreamComment(Result, "DCR", FlushRulesTable.Rows.Count() <> 0);
	ExportHandlersOfDataClearRules(Result, FlushRulesTable.Rows);
	
	// Exporting OCR, PCR, PGCR.
	ExportConversionRulesHandlers(Result);
	
	If AlgorithmsDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		// Export Algorithms with standard parameters (with default parameters).
		DumpAlgorithms(Result);
		
	EndIf; 
	
	// Output comments
	AddInStreamComment(Result, "Warning");
	AddInStreamComment(Result, "CommonProcedureFunctions");
		
	// Output general procedures and functions to stream.
	AddInStreamServiceCode(Result, "CommonProcedureFunctions");

	// Output external processor constructor.
	ExportExternalDataProcessorAssistant(Result);
	
	// Output destructor
	AddInStreamServiceCode(Result, "Destructor");
	
	Result.Close();
	
	FinishExchangeProtocolLogging();
	
	If ThisIsInteractiveMode Then
		
		If ErrorFlag Then
			
			MessageToUser(NStr("en='Errors were found while exporting handlers.';ru='При выгрузке обработчиков были обнаружены ошибки.'"));
			
		Else
			
			MessageToUser(NStr("en='Handlers are exported successfully.';ru='Обработчики успешно выгружены.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Clears variables with exchange rules structure.
//
// Parameters:
//  No.
//  
Procedure ClearExchangeRules()
	
	UnloadRulesTable.Rows.Clear();
	FlushRulesTable.Rows.Clear();
	ConversionRulesTable.Clear();
	Algorithms.Clear();
	Queries.Clear();

	// DataProcessors
	AdditionalInformationProcessors.Clear();
	AdditionalInformationProcessorParameters.Clear();
	DumpConfigurationProcedures.Clear();
	ImportConfigurationProcedures.Clear();

EndProcedure  

// Imports exchange rules from rules file or data file.
//
// Parameters:
//  No.
//  
Procedure ImportExchangeRulesForExportOfHandlers()
	
	ClearExchangeRules();
	
	If EventHandlersReadFromFileOfExchangeRules Then
		
		ExchangeMode = ""; // Export

		ImportExchangeRules();
		
		mExchangeRulesReadOnImport = False;
		
		InitializeInitialParameterValues();
		
	Else // data file
		
		ExchangeMode = "Import"; 
		
		If IsBlankString(ExchangeFileName) Then
			WriteInExecutionProtocol(15);
			Return;
		EndIf;
		
		OpenImportFile(True);
		
		// If there is a check
		// box, data processor will require to reread rules while trying to export data.
		mExchangeRulesReadOnImport = True;

	EndIf;
	
EndProcedure

// Exports global conversion handlers to the text file.
//  
// Parameters:
//  Result - Object of the TextWriting type - for handlers output to the text file.
//  
// Note:
//  "Conversion_AfterParametersImport" handler content is not
// exported while exporting handlers from file with data as handler code is not in the exchange rules node but in the separate node.
//  This algorithm is exported like the other ones while exporting handlers from file.
Procedure ExportConversionHandlers(Result)
	
	AddInStreamComment(Result, "Conversion");
	
	For Each Item IN HandlerNames.Conversion Do
		
		AddInStreamConversionHandler(Result, Item.Key);
		
	EndDo; 
	
EndProcedure 

// Exports data export rule handlers to the text file.
//
// Parameters:
//  Result    - Object of the TextWriting type - for handlers output to the text file.
//  TreeRows - Object of the ValuesTreeStringsCollection type - contains DDR of the specified level of the value tree.
// 
Procedure ExportDumpRulesHandlers(Result, TreeRows)
	
	For Each Rule IN TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportDumpRulesHandlers(Result, Rule.Rows); 
			
		Else
			
			For Each Item IN HandlerNames.DDR Do
				
				AddInStreamHandler(Result, Rule, "DDR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports data clearing rule handlers to the text file.
//
// Parameters:
//  Result    - Object of the TextWriting type - for handlers output to the text file.
//  TreeRows - Object of the ValuesTreeStringsCollection type - contains DCR of the specified level of the value tree.
// 
Procedure ExportHandlersOfDataClearRules(Result, TreeRows)
	
	For Each Rule IN TreeRows Do
		
		If Rule.IsFolder Then
			
			ExportHandlersOfDataClearRules(Result, Rule.Rows); 
			
		Else
			
			For Each Item IN HandlerNames.DCR Do
				
				AddInStreamHandler(Result, Rule, "DCR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Exports conversion rule handlers: OCR, PCR, PGCR to the text file.
//
// Parameters:
//  Result    - Object of the TextWriting type - for handlers output to the text file.
// 
Procedure ExportConversionRulesHandlers(Result)
	
	DisplayComment = ConversionRulesTable.Count() <> 0;
	
	// Exporting OCR.
	AddInStreamComment(Result, "OCR", DisplayComment);
	
	For Each OCR IN ConversionRulesTable Do
		
		For Each Item IN HandlerNames.OCR Do
			
			AddInStreamOCRHandler(Result, OCR, Item.Key);
			
		EndDo; 
		
	EndDo; 
	
	// Exporting OCR and PGCR.
	AddInStreamComment(Result, "PCR", DisplayComment);
	
	For Each OCR IN ConversionRulesTable Do
		
		ExportHandlersOfPropertyConversionRules(Result, OCR.SearchProperties);
		ExportHandlersOfPropertyConversionRules(Result, OCR.Properties);
		
	EndDo; 
	
EndProcedure 

// Exports properties conversion rule handlers to the text file.
//
// Parameters:
//  Result - Object of the TextWriting type - for handlers output to the text file.
//  PCR       - ValueTable - contains properties conversion rules or object property groups.
// 
Procedure ExportHandlersOfPropertyConversionRules(Result, PCR)
	
	For Each Rule IN PCR Do
		
		If Rule.IsFolder Then // PGCR
			
			For Each Item IN HandlerNames.PGCR Do
				
				AddInStreamOCRHandler(Result, Rule, Item.Key);
				
			EndDo; 

			ExportHandlersOfPropertyConversionRules(Result, Rule.GroupRules);
			
		Else
			
			For Each Item IN HandlerNames.PCR Do
				
				AddInStreamOCRHandler(Result, Rule, Item.Key);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Exports algorithms to the text file.
//
// Parameters:
//  Result - Object of the TextWriting type - to output algorithms to the text file.
// 
Procedure DumpAlgorithms(Result)
	
	// Comment to the "Algorithms" block.
	AddInStreamComment(Result, "Algorithms", Algorithms.Count() <> 0);
	
	For Each Algorithm IN Algorithms Do
		
		AddInStreamAlgorithm(Result, Algorithm);
		
	EndDo; 
	
EndProcedure  

// Exports external processor constructor to the text file.
//  If there is algorithms debugging mode - "debug algorithms as procedures", "Algorithms" structure
//  is added to the constructor.
//  Structure item key - algorithm name, value - interface of the procedure call containing algorithm code.
//
// Parameters:
//  Result    - Object of the TextWriting type - for handlers output to the text file.
// 
Procedure ExportExternalDataProcessorAssistant(Result)
	
	// Output comment
	AddInStreamComment(Result, "Assistant");
	
	ProcedureBody = GetServiceCode("Constructor_ProcedureBody");

	If AlgorithmsDebugMode = mAlgorithmDebugModes.ProceduralCall Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_ProceduralAlgorithmCall");
		
		// Add Algorithm calls to the algorithm body.
		For Each Algorithm IN Algorithms Do
			
			AlgorithmKey = TrimAll(Algorithm.Key);
			
			AlgorithmInterface = GetAlgorithmInterface(AlgorithmKey) + ";";
			
			AlgorithmInterface = StrReplace(StrReplace(AlgorithmInterface, Chars.LF, " ")," ","");
			
			ProcedureBody = ProcedureBody + Chars.LF 
			   + "Algorithms.Insert(""" + AlgorithmKey + """, """ + AlgorithmInterface + """);";

			
		EndDo; 
		
	ElsIf AlgorithmsDebugMode = mAlgorithmDebugModes.CodeIntegration Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_AlgorithmCodeIntegration");
		
	ElsIf AlgorithmsDebugMode = mAlgorithmDebugModes.DontUse Then
		
		ProcedureBody = ProcedureBody + GetServiceCode("Constructor_ProcedureBody_DontUseAlgorithmDebug");
		
	EndIf; 
	
	ExternalDataProcessorProcedureInterface = "Procedure " + GetInterfaceOfProcedureOfExternalDataProcessor("Assistant") + " Export";
	
	AddInStreamFullHandler(Result, ExternalDataProcessorProcedureInterface, ProcedureBody);
	
EndProcedure  


// Adds OCR, PCR or PGCR handler to the "Result" object.
//
// Parameters:
//  Result      - Object of the TextWriting type - to output handler to the text file.
//  Rule        - values table row with object conversion rules.
//  HandlerName - String - handler name.
//  
Procedure AddInStreamOCRHandler(Result, Rule, HandlerName)
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddInStreamFullHandler(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds algorithm code to the "Result" object.
//
// Parameters:
//  Result - Object of the TextWriting type - to output handler to the text file.
//  Algorithm  - structure item - algorithm for export.
//  
Procedure AddInStreamAlgorithm(Result, Algorithm)
	
	AlgorithmInterface = "Procedure " + GetAlgorithmInterface(Algorithm.Key);

	AddInStreamFullHandler(Result, AlgorithmInterface, Algorithm.Value);
	
EndProcedure  

// Adds handler DDR or DCR to object "Result".
//
// Parameters:
//  Result      - Object of the TextWriting type - to output handler to the text file.
//  Rule        - values tree string with rules.
//  HandlerPrefix - String - handler prefix: "DDR" or "DCR".
//  HandlerName - String - handler name.
//  
Procedure AddInStreamHandler(Result, Rule, HandlerPrefix, HandlerName)
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	HandlerInterface = "Procedure " + Rule["HandlerInterface" + HandlerName] + " Export";
	
	AddInStreamFullHandler(Result, HandlerInterface, Rule[HandlerName]);
	
EndProcedure  

// Adds conversion global handler to the "Result" object.
//
// Parameters:
//  Result      - Object of the TextWriting type - to output handler to the text file.
//  HandlerName - String - handler name.
//  
Procedure AddInStreamConversionHandler(Result, HandlerName)
	
	HandlerAlgorithm = "";
	
	If Conversion.Property(HandlerName, HandlerAlgorithm) AND Not IsBlankString(HandlerAlgorithm) Then
		
		HandlerInterface = "Procedure " + Conversion["HandlerInterface" + HandlerName] + " Export";
		
		AddInStreamFullHandler(Result, HandlerInterface, HandlerAlgorithm);
		
	EndIf;
	
EndProcedure  

// Adds procedure with handler code or algorithm code to the "Result" object.
//
// Parameters:
//  Result            - Object of the TextWriting type - to output procedure to the text file.
//  HandlerInterface - String - full description of the handler interface:
//                         procedure name, procedure parameters, "Export" key word.
//  Handler           - String - body of the handler or algorithm.
//
Procedure AddInStreamFullHandler(Result, HandlerInterface, Handler)
	
	PrefixString = Chars.Tab;
	
	Result.WriteLine("");
	
	Result.WriteLine(HandlerInterface);
	
	Result.WriteLine("");
	
	For IndexOf = 1 To StrLineCount(Handler) Do
		
		HandlerLine = StrGetLine(Handler, IndexOf);
		
		// IN the debugging mode of "Code integration" algorithms insert algorithms code directly to the handler code. Insert algorithm code instead of its call.
		// IN the algorithms code algorithms nesting is already considered.
		If AlgorithmsDebugMode = mAlgorithmDebugModes.CodeIntegration Then
			
			HandlerAlgorithms = GetHandlerAlgorithms(HandlerLine);
			
			If HandlerAlgorithms.Count() <> 0 Then // IN this string there are algorithms calls.
				
				// Receive initial algorithm code shift relative to the current handler code.
				PrefixStringForInlineCode = GetPrefixForNestedAlgorithm(HandlerLine, PrefixString);
				
				For Each Algorithm IN HandlerAlgorithms Do
					
					AlgorithmHandler = IntegratedAlgorithms[Algorithm];
					
					For AlgorithmRowIndex = 1 To StrLineCount(AlgorithmHandler) Do
						
						Result.WriteLine(PrefixStringForInlineCode + StrGetLine(AlgorithmHandler, AlgorithmRowIndex));
						
					EndDo;	
					
				EndDo;
				
			EndIf;
		EndIf;

		Result.WriteLine(PrefixString + HandlerLine);
		
	EndDo;
	
	Result.WriteLine("");
	Result.WriteLine("EndProcedure");
	
EndProcedure

// Adds comment to the "Result" object.
//
// Parameters:
//  Result          - Object of the TextWriting type - to output comment to a text file.
//  AreaName         - String - "TemplateGeneralProceduresAndFunctions" text
// template field name which contains the required comment.
//  DisplayComment - Boolean - shows that it is required to output comment.
//
Procedure AddInStreamComment(Result, AreaName, DisplayComment = True)
	
	If Not DisplayComment Then
		Return;
	EndIf; 
	
	// Receive handler comments by the area name.
	CurrentArea = mCommonProcedureFunctionsTemplate.GetArea(AreaName+"_Comment");
	
	CommentFromTemplate = TrimAll(GetTextByAreaWithoutAreaName(CurrentArea));
	
	// Exclude the last string transfer.
	CommentFromTemplate = Mid(CommentFromTemplate, 1, StrLen(CommentFromTemplate));
	
	Result.WriteLine(Chars.LF + Chars.LF + CommentFromTemplate);
	
EndProcedure  

// Adds service code to the "Result" object: parameters, general procedures and functions, external data processor destructor.
//
// Parameters:
//  Result          - Object of the TextWriting type - to output service code to the text file.
//  AreaName         - String - "TemplateGeneralProceduresAndFunctions" text
// template area name which contains the required service code.
//
Procedure AddInStreamServiceCode(Result, AreaName)
	
	// Receive area text
	CurrentArea = mCommonProcedureFunctionsTemplate.GetArea(AreaName);
	
	Text = TrimAll(GetTextByAreaWithoutAreaName(CurrentArea));
	
	Text = Mid(Text, 1, StrLen(Text)); // Exclude the last string transfer.
	
	Result.WriteLine(Chars.LF + Chars.LF + Text);
	
EndProcedure  

// Receives service code from the specified "TemplateGeneralProceduresAndFunctions" template area.
//  
// Parameters:
//  AreaName - String - "TemplateGeneralProceduresAndFunctions" text template area name.
//  
// Returns:
//  Text from the template
//
Function GetServiceCode(AreaName)
	
	// Receive area text
	CurrentArea = mCommonProcedureFunctionsTemplate.GetArea(AreaName);
	
	Return GetTextByAreaWithoutAreaName(CurrentArea);
EndFunction

//////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF RECEIVING FULL ALGORITHM CODE CONSIDERING THEIR NESTING

// Generates full algorithms code considering their nesting.
//
// Parameters:
//  No.
//  
Procedure GetFullCodeOfAlgorithmsWithHierarchy()
	
	// Fill in integrated algorithms structure.
	IntegratedAlgorithms = New Structure;
	
	For Each Algorithm IN Algorithms Do
		
		IntegratedAlgorithms.Insert(Algorithm.Key, ReplaceAlgorithmCallsByCodeOfTheseAlgorithmsInHandler(Algorithm.Value, Algorithm.Key, New Array));
		
	EndDo; 
	
EndProcedure 

// Adds the "HandlerNew" string with the comment to another algorithm code insert.
//
// Parameters:
//  NewHandler - String - total string containing the full algorithm code considering algorithms nesting.
//  AlgorithmName    - String - algorithm name.
//  PrefixString  - String - specifies an initial shift of the output comment.
//  Title       - String - comment name: "(ALGORITHM START)", "(ALGORITHM END)"...
//
Procedure WriteTitleBlockAlgorithm(NewHandler, AlgorithmName, PrefixString, Title) 
	
	AlgorithmTitle = "//============================ " + Title + " """ + AlgorithmName + """ ============================";
	
	NewHandler = NewHandler + Chars.LF;
	NewHandler = NewHandler + Chars.LF + PrefixString + AlgorithmTitle;
	NewHandler = NewHandler + Chars.LF;
	
EndProcedure  

// Expands the "HandlerAlgorithms" array with algorithm names that are called from the passed "HandlerString" handler procedure string.
//
// Parameters:
//  HandlerLine - String - String of handler or algorithm in which algorithm calls are searched.
//  HandlerAlgorithms - Array- contains names of algorithms that are called from the specified handler.
//  
Procedure GetAlgorithmsOfHandlerLine(HandlerLine, HandlerAlgorithms)
	
	HandlerLine = Upper(HandlerLine);
	
	SearchPattern = "ALGORITHMS.";
	
	PatternStringLength = StrLen(SearchPattern);
	
	InitialChar = Find(HandlerLine, SearchPattern);
	
	If InitialChar = 0 Then
		// There are no algorithms in this string or all algorithms from this string are already considered.
		Return; 
	EndIf;
	
	// Check whether there is a flag showing that operator is commented.
	HandlerLineBeforeAlgorithmCall = Left(HandlerLine, InitialChar);
	
	If Find(HandlerLineBeforeAlgorithmCall, "//") <> 0  Then 
		// This operator and the further ones are commented.
		// Exit the cycle.
		Return;
	EndIf; 
	
	HandlerLine = Mid(HandlerLine, InitialChar + PatternStringLength);
	
	EndChar = Find(HandlerLine, ")") - 1;
	
	AlgorithmName = Mid(HandlerLine, 1, EndChar); 
	
	HandlerAlgorithms.Add(TrimAll(AlgorithmName));
	
	// See handler string up till the end until all algorithm calls from this string are not considered.
	GetAlgorithmsOfHandlerLine(HandlerLine, HandlerAlgorithms);
	
EndProcedure 

// Function returns changed algorithm code considering nested algorithms. Instead of
// algorithm call operator "Execute(Algorithms.Algorithm_1);" full code of the called algorithm is inserted with "PrefixString" shift.
// Function recursively calls itself until all nested algorithms are considered.
//  
// Parameters:
//  Handler                 - String - initial algorithm code.
//  PrefixString             - String - shift value of the inserted algorithm code.
//  AlgorithmOwner           - String - algorithm name which is a parent
// one relatively to the algorithm code of which is processed by this function.
//  RequestedItemArray - Array - contains algorithm names which are already processed in this recursion branch.
//                                        It is required to prevent
//                                        infinite recursion of function and output error warning.
//  
// Returns:
//  NewHandler - String - changed algorithm code considering nested algorithms.
// 
Function ReplaceAlgorithmCallsByCodeOfTheseAlgorithmsInHandler(Handler, AlgorithmOwner, RequestedItemArray, Val PrefixString = "")
	
	RequestedItemArray.Add(Upper(AlgorithmOwner));
	
	// Initialize return value.
	NewHandler = "";
	
	WriteTitleBlockAlgorithm(NewHandler, AlgorithmOwner, PrefixString, NStr("en='{ALGORITHM START}';ru='{НАЧАЛО АЛГОРИТМА}'"));
	
	For IndexOf = 1 To StrLineCount(Handler) Do
		
		HandlerLine = StrGetLine(Handler, IndexOf);
		
		HandlerAlgorithms = GetHandlerAlgorithms(HandlerLine);
		
		If HandlerAlgorithms.Count() <> 0 Then // IN this string there are algorithms calls.
			
			// Receive algorithm code initial shift relative to the current code.
			PrefixStringForInlineCode = GetPrefixForNestedAlgorithm(HandlerLine, PrefixString);
				
			// Expand a full code of each algorithm which was called from the "HandlerString" string.
			For Each Algorithm IN HandlerAlgorithms Do
				
				If RequestedItemArray.Find(Upper(Algorithm)) <> Undefined Then // Recursive algorithm call.
					
					WriteTitleBlockAlgorithm(NewHandler, Algorithm, PrefixStringForInlineCode, NStr("en='{RECURSIVE ALGORITHM CALL}';ru='{RECURSIVE ALGORITHM CALL}'"));
					
					OperatorString = NStr("en='CallException ""RECURSIVE ALGORITHM CALL: %1"";';ru='ВызватьИсключение ""РЕКУРСИВНЫЙ ВЫЗОВ АЛГОРИТМА: %1"";'");
					OperatorString = PlaceParametersIntoString(OperatorString, Algorithm);
					
					NewHandler = NewHandler + Chars.LF + PrefixStringForInlineCode + OperatorString;
					
					WriteTitleBlockAlgorithm(NewHandler, Algorithm, PrefixStringForInlineCode, NStr("en='{RECURSIVE ALGORITHM CALL}';ru='{RECURSIVE ALGORITHM CALL}'"));
					
					RecordStructure = New Structure;
					RecordStructure.Insert("Algorithm_1", AlgorithmOwner);
					RecordStructure.Insert("Algorithm_2", Algorithm);
					
					WriteInExecutionProtocol(79, RecordStructure);
					
				Else
					
					NewHandler = NewHandler + ReplaceAlgorithmCallsByCodeOfTheseAlgorithmsInHandler(Algorithms[Algorithm], Algorithm, CopyArray(RequestedItemArray), PrefixStringForInlineCode);
					
				EndIf; 
				
			EndDo;
			
		EndIf; 
		
		NewHandler = NewHandler + Chars.LF + PrefixString + HandlerLine; 
		
	EndDo;
	
	WriteTitleBlockAlgorithm(NewHandler, AlgorithmOwner, PrefixString, NStr("en='{ALGORITHM END}';ru='{КОНЕЦ АЛГОРИТМА}'"));
	
	Return NewHandler;
	
EndFunction

// Copies passed array and returns the new one.
//  
// Parameters:
//  ArraySource - Array - source for receiving a new array by copying.
//  
// Returns:
//  NewArray - Array - array received by copying from the passed array.
// 
Function CopyArray(ArraySource)
	
	NewArray = New Array;
	
	For Each ArrayElement IN ArraySource Do
		
		NewArray.Add(ArrayElement);
		
	EndDo; 
	
	Return NewArray;
EndFunction 

// Returns an array with algorithm names that were found in the passed handler body.
//  
// Parameters:
//  Handler - String - handler body.
//  
// Returns:
//  HandlerAlgorithms - Array - array with algorithm names that are present in the passed handler.
//
Function GetHandlerAlgorithms(Handler)
	
	// Initialize return value.
	HandlerAlgorithms = New Array;
	
	For IndexOf = 1 To StrLineCount(Handler) Do
		
		HandlerLine = TrimL(StrGetLine(Handler, IndexOf));
		
		If Left(HandlerLine, 2) = "//" Then //String is commented, skip it.
			Continue;
		EndIf;
		
		GetAlgorithmsOfHandlerLine(HandlerLine, HandlerAlgorithms);
		
	EndDo;
	
	Return HandlerAlgorithms;
EndFunction 

// Receives prefix string to output nested algorithm code.
//
// Parameters:
//  HandlerLine - String - String from which the call
//                      shift value is extracted (shift during which algorithm is called).
//  PrefixString    - String - initial shift.
// Returns:
//  PrefixStringForInlineCode - String - Total algorithm code shift.
// 
Function GetPrefixForNestedAlgorithm(HandlerLine, PrefixString)
	
	HandlerLine = Upper(HandlerLine);
	
	TemplatePositionNumberExecute = Find(HandlerLine, "Execute");
	
	PrefixStringForInlineCode = PrefixString + Left(HandlerLine, TemplatePositionNumberExecute - 1) + Chars.Tab;
	
	// If there is an algorithm (algorithms) call in the handler string, then delete the string from code.
	HandlerLine = "";
	
	Return PrefixStringForInlineCode;
EndFunction 

//////////////////////////////////////////////////////////////////////////////
// FORMATTING FUNCTIONS OF UNIQUE NAME OF EVENT HANDLERS

// Generates interface of PCR, PGCR handler (unique procedure name with parameters of a correspondent handler).
//
// Parameters:
//  OCR            - Values table row - contains object conversion rule.
//  PGCR           - Values table row - contains properties group conversion rule.
//  Rule        - Values table row - contains object properties conversion rule.
//  HandlerName - String - event handler name.
//
// Returns:
//  String - interface handler.
// 
Function GetPCRHandlerInterface(OCR, PGCR, Rule, HandlerName)
	
	AreaName = "PK" + ?(Rule.IsFolder, "G", "") + "From_" + HandlerName;
	
	OwnerName = "_" + TrimAll(OCR.Name);
	
	ParentName  = "";
	
	If PGCR <> Undefined Then
		
		If Not IsBlankString(PGCR.TargetKind) Then 
			
			ParentName = "_" + TrimAll(PGCR.Receiver);	
			
		EndIf; 
		
	EndIf; 
	
	TargetName = "_" + TrimAll(Rule.Receiver);
	TargetKind = "_" + TrimAll(Rule.TargetKind);
	
	PropertyCode = TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + OwnerName + ParentName + TargetName + TargetKind + PropertyCode;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates interface of OCR, DDR, DCR handler (unique procedure name with parameters of a correspondent handler).
//
// Parameters:
//  Rule            - custom values collection - OCR, DDR, DCR.
//  HandlerPrefix - String - possible values: "OCR", "DDR", "DCR".
//  HandlerName     - String - event handler name for this rule.
//
// Returns:
//  String - interface handler.
// 
Function GetHandlerInterface(Rule, HandlerPrefix, HandlerName)
	
	AreaName = HandlerPrefix + "_" + HandlerName;
	
	Rulename = "_" + TrimAll(Rule.Name);
	
	FullHandlerName = AreaName + Rulename;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates interface of the conversion global handler (unique procedure name
// with parameters of a correspondent handler).
//
// Parameters:
//  HandlerName - String - conversion event handler name.
//
// Returns:
//  String - interface handler.
// 
Function GetHandlerInterfaceConversion(HandlerName)
	
	AreaName = "Conversion_" + HandlerName;
	
	FullHandlerName = AreaName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates procedure interface (of a constructor or a destructor) for an external data processor.
//
// Parameters:
//  ProcedureName - String - procedure name.
//
// Returns:
//  String - procedure interface.
// 
Function GetInterfaceOfProcedureOfExternalDataProcessor(ProcedureName)
	
	AreaName = "DataProcessor_" + ProcedureName;
	
	FullHandlerName = ProcedureName;
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

// Generates algorithm interface for an external data processor.
// Receive the same set of default parameters for all algorithms.
//
// Parameters:
//  AlgorithmName - String - algorithm name.
//
// Returns:
//  String - algorithm interface.
// 
Function GetAlgorithmInterface(AlgorithmName)
	
	FullHandlerName = "Algorithm_" + AlgorithmName;
	
	AreaName = "Algorithm_Default";
	
	Return FullHandlerName + "(" + GetHandlerParameters(AreaName) + ")";
EndFunction 

Function GetHandlerCallString(Rule, HandlerName)
	
	Return "EventHandlerExternalDataProcessor." + Rule["HandlerInterface" + HandlerName] + ";";
	
EndFunction 

Function GetTextByAreaWithoutAreaName(Area)
	
	AreaText = Area.GetText();
	
	If Find(AreaText, "#Region") > 0 Then
	
		FirstLinefeed = Find(AreaText, Chars.LF);
		
		AreaText = Mid(AreaText, FirstLinefeed + 1);
		
	EndIf;
	
	Return AreaText;
	
EndFunction

Function GetHandlerParameters(AreaName)
	
	NewLineString = Chars.LF + "                                           ";
	
	HandlerParameters = "";
	
	TotalString = "";
	
	Area = mHandlerParameterTemplate.GetArea(AreaName);
	
	ParameterArea = Area.Areas[AreaName];
	
	For LineNumber = ParameterArea.Top To ParameterArea.Bottom Do
		
		CurrentArea = Area.GetArea(LineNumber, 2, LineNumber, 2);
		
		Parameter = TrimAll(CurrentArea.CurrentArea.Text);
		
		If Not IsBlankString(Parameter) Then
			
			HandlerParameters = HandlerParameters + Parameter + ", ";
			
			TotalString = TotalString + Parameter;
			
		EndIf; 
		
		If StrLen(TotalString) > 50 Then
			
			TotalString = "";
			
			HandlerParameters = HandlerParameters + NewLineString;
			
		EndIf; 
		
	EndDo;
	
	HandlerParameters = TrimAll(HandlerParameters);
	
	// Remove the last sign "," and return the string.
	
	Return Mid(HandlerParameters, 1, StrLen(HandlerParameters) - 1); 
EndFunction 


////////////////////////////////////////////////////////////////////////////////
// INTERFACE CREATION PROCEDURES OF HANDLERS CALL IN THE EXCHANGE RULES

// Expands existing collections with exchange rules of handlers call interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains conversion rules and global handlers.
//  OCRTable           - ValueTable - contains objects conversion rules.
//  DDRTable           - ValueTree - contains data export rules.
//  DCRTable           - ValueTree - contains data clearing rules.
//  
Procedure SupplementRulesWithInterfacesOfHandlers(ConversionStructure, OCRTable, DDRTable, DCRTable) Export
	
	mHandlerParameterTemplate = GetTemplate("ParametersOfHandlers");
	
	// Add Conversion interfaces (global).
	SupplementWithInterfacesOfHandlersConversionRules(ConversionStructure);
	
	// Add interfaces DDR
	SupplementWithInterfacesOfHandlersRulesOfDataDump(DDRTable, DDRTable.Rows);
	
	// Add DCR interfaces
	SupplementWithInterfacesOfHandlersDataClearRules(DCRTable, DCRTable.Rows);
	
	// Add interfaces OCR, PCR, PGCR.
	SupplementWithInterfacesOfHandlersObjectConversionRules(OCRTable);
	
EndProcedure 

// Expands collection of data clearing rule values with handler interfaces.
//
// Parameters:
//  DCRTable   - ValueTree - contains data clearing rules.
//  TreeRows - Object of the ValuesTreeStringsCollection type - contains DCR of the specified level of the value tree.
//  
Procedure SupplementWithInterfacesOfHandlersDataClearRules(DCRTable, TreeRows)
	
	For Each Rule IN TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementWithInterfacesOfHandlersDataClearRules(DCRTable, Rule.Rows); 
			
		Else
			
			For Each Item IN HandlerNames.DCR Do
				
				AdditHandlerInterface(DCRTable, Rule, "DCR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Expands collection of data export rule values with handler interfaces.
//
// Parameters:
//  DDRTable   - ValueTree - contains data export rules.
//  TreeRows - Object of the ValuesTreeStringsCollection type - contains DDR of the specified level of the value tree.
//  
Procedure SupplementWithInterfacesOfHandlersRulesOfDataDump(DDRTable, TreeRows) 
	
	For Each Rule IN TreeRows Do
		
		If Rule.IsFolder Then
			
			SupplementWithInterfacesOfHandlersRulesOfDataDump(DDRTable, Rule.Rows); 
			
		Else
			
			For Each Item IN HandlerNames.DDR Do
				
				AdditHandlerInterface(DDRTable, Rule, "DDR", Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  

// Expands the conversion structure with handler interfaces.
//
// Parameters:
//  ConversionStructure - Structure - contains conversion rules and global handlers.
//  
Procedure SupplementWithInterfacesOfHandlersConversionRules(ConversionStructure) 
	
	For Each Item IN HandlerNames.Conversion Do
		
		AddConversionHandlerInterface(ConversionStructure, Item.Key);
		
	EndDo; 
	
EndProcedure  

// Expands collection of data conversion rule values with handler interfaces.
//
// Parameters:
//  OCRTable - ValueTable - contains objects conversion rules.
//  
Procedure SupplementWithInterfacesOfHandlersObjectConversionRules(OCRTable)
	
	For Each OCR IN OCRTable Do
		
		For Each Item IN HandlerNames.OCR Do
			
			AddOCRHandlerInterface(OCRTable, OCR, Item.Key);
			
		EndDo; 
		
		// Add interfaces for PCR.
		SupplementWithInterfacesOfPCRHandlers(OCR, OCR.SearchProperties);
		SupplementWithInterfacesOfPCRHandlers(OCR, OCR.Properties);
		
	EndDo; 
	
EndProcedure

// Expands values collection of object properties conversion rules with handler interfaces.
//
// Parameters:
//  OCR - Values table row    - contains object conversion rule.
//  ObjectPropertyConversionRules - ValueTable - contains properties conversion rules or
//                                                       object properties group from OCR rule.
//  PGCR - Values table row   - contains properties group conversion rule.
//  
Procedure SupplementWithInterfacesOfPCRHandlers(OCR, ObjectPropertyConversionRules, PGCR = Undefined)
	
	For Each PCR IN ObjectPropertyConversionRules Do
		
		If PCR.IsFolder Then // PGCR
			
			For Each Item IN HandlerNames.PGCR Do
				
				AddPCRHandlerInterface(ObjectPropertyConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 

			SupplementWithInterfacesOfPCRHandlers(OCR, PCR.GroupRules, PCR);
			
		Else
			
			For Each Item IN HandlerNames.PCR Do
				
				AddPCRHandlerInterface(ObjectPropertyConversionRules, OCR, PGCR, PCR, Item.Key);
				
			EndDo; 
			
		EndIf; 
		
	EndDo; 
	
EndProcedure  


Procedure AdditHandlerInterface(Table, Rule, HandlerPrefix, HandlerName) 
	
	If IsBlankString(Rule[HandlerName]) Then
		Return;
	EndIf;
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
		
	Rule[FieldName] = GetHandlerInterface(Rule, HandlerPrefix, HandlerName);
	
EndProcedure 

Procedure AddOCRHandlerInterface(Table, Rule, HandlerName) 
	
	If Not Rule["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	Rule[FieldName] = GetHandlerInterface(Rule, "OCR", HandlerName);
  
EndProcedure 

Procedure AddPCRHandlerInterface(Table, OCR, PGCR, PCR, HandlerName) 
	
	If Not PCR["HasHandler" + HandlerName] Then
		Return;
	EndIf; 
	
	FieldName = "HandlerInterface" + HandlerName;
	
	AddMissingColumns(Table.Columns, FieldName);
	
	PCR[FieldName] = GetPCRHandlerInterface(OCR, PGCR, PCR, HandlerName);
	
EndProcedure  

Procedure AddConversionHandlerInterface(ConversionStructure, HandlerName)
	
	HandlerAlgorithm = "";
	
	If ConversionStructure.Property(HandlerName, HandlerAlgorithm) AND Not IsBlankString(HandlerAlgorithm) Then
		
		FieldName = "HandlerInterface" + HandlerName;
		
		ConversionStructure.Insert(FieldName);
		
		ConversionStructure[FieldName] = GetHandlerInterfaceConversion(HandlerName); 
		
	EndIf;
	
EndProcedure  


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF WORK WITH EXCHANGE RULES

// Search for conversion rule by name or according
// to the passed object type.
//
// Parameters:
//  Object         - Object-source for which you should search for conversion rule.
//  Rulename     - conversion rule name.
//
// Returns:
//  Ref to conversion rule (row in rules table).
// 
Function FindRule(Object, Rulename="") Export

	If Not IsBlankString(Rulename) Then
		
		Rule = Rules[Rulename];
		
	Else
		
		Rule = Managers[TypeOf(Object)];
		If Rule <> Undefined Then
			Rule    = Rule.OCR;
			
			If Rule <> Undefined Then 
				Rulename = Rule.Name;
			EndIf;
			
		EndIf; 
		
	EndIf;
	
	Return Rule; 
	
EndFunction

// Saves exchange rules to the internal format.
//
// Parameters:
//  No.
// 
Procedure SaveRulesInInternalFormat() Export

	For Each Rule IN ConversionRulesTable Do
		Rule.Exported.Clear();
		Rule.OnlyRefsExported.Clear();
	EndDo;

	RuleStructure = New Structure;
	
	// Save queries
	QueriesToSave = New Structure;
	For Each StructureItem IN Queries Do
		QueriesToSave.Insert(StructureItem.Key, StructureItem.Value.Text);
	EndDo;

	ParametersToSave = New Structure;
	For Each StructureItem IN Parameters Do
		ParametersToSave.Insert(StructureItem.Key, Undefined);
	EndDo;

	RuleStructure.Insert("UnloadRulesTable",      UnloadRulesTable);
	RuleStructure.Insert("ConversionRulesTable",   ConversionRulesTable);
	RuleStructure.Insert("Algorithms",                  Algorithms);
	RuleStructure.Insert("Queries",                    QueriesToSave);
	RuleStructure.Insert("Conversion",                Conversion);
	RuleStructure.Insert("mXMLRules",                mXMLRules);
	RuleStructure.Insert("ParametersSettingsTable", ParametersSettingsTable);
	RuleStructure.Insert("Parameters",                  ParametersToSave);
	
	RuleStructure.Insert("TargetPlatformVersion",   TargetPlatformVersion);
	
	SavedSettings  = New ValueStorage(RuleStructure);
	
EndProcedure

Function DefinePlatformByReceiverPlatformVersion(PlatformVersion)
	
	If Find(PlatformVersion, "8.") > 0 Then
		
		Return "V8";
		
	Else
		
		Return "V7";
		
	EndIf;	
	
EndFunction

// Restores rules from the internal format.
//
// Parameters:
// 
Procedure RestoreRulesFromInternalFormat() Export

	If SavedSettings = Undefined Then
		Return;
	EndIf;
	
	RuleStructure = SavedSettings.Get();

	UnloadRulesTable      = RuleStructure.UnloadRulesTable;
	ConversionRulesTable   = RuleStructure.ConversionRulesTable;
	Algorithms                  = RuleStructure.Algorithms;
	QueriesToRestore   = RuleStructure.Queries;
	Conversion                = RuleStructure.Conversion;
	mXMLRules                = RuleStructure.mXMLRules;
	ParametersSettingsTable = RuleStructure.ParametersSettingsTable;
	Parameters                  = RuleStructure.Parameters;
	
	SupplementSystemTablesWithColumns();
	
	RuleStructure.Property("TargetPlatformVersion", TargetPlatformVersion);
	
	TargetPlatform = DefinePlatformByReceiverPlatformVersion(TargetPlatformVersion);
		
	HasBeforeObjectExportGlobalHandler    = Not IsBlankString(Conversion.BeforeObjectExport);
	HasAfterObjectExportGlobalHandler     = Not IsBlankString(Conversion.AfterObjectExport);
	HasBeforeObjectImportGlobalHandler    = Not IsBlankString(Conversion.BeforeObjectImport);
	HasAftertObjectImportGlobalHandler     = Not IsBlankString(Conversion.AftertObjectImport);
	HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);

	// Restore queries
	Queries.Clear();
	For Each StructureItem IN QueriesToRestore Do
		Query = New Query(StructureItem.Value);
		Queries.Insert(StructureItem.Key, Query);
	EndDo;

	InitializeManagersAndMessages();
	
	Rules.Clear();
	ClearOCROfManagers();
	
	If ExchangeMode = "Export" Then
	
		For Each TableRow IN ConversionRulesTable Do
			Rules.Insert(TableRow.Name, TableRow);

			If TableRow.Source <> Undefined Then
				
				Try
					If TypeOf(TableRow.Source) = deStringType Then
						Managers[Type(TableRow.Source)].OCR = TableRow;
					Else
						Managers[TableRow.Source].OCR = TableRow;
					EndIf;			
				Except
					WriteInformationAboutErrorToProtocol(11, ErrorDescription(), String(TableRow.Source));
				EndTry;
				
			EndIf;

		EndDo;
	
	EndIf;	
	
EndProcedure

// Sets parameter values in the Parameters structure according to the ParametersSettingsTable table.
// 
Procedure SetParametersFromDialog() Export

	For Each TableRow IN ParametersSettingsTable Do
		Parameters.Insert(TableRow.Name, TableRow.Value);
	EndDo;

EndProcedure

// Sets parameter value to the parameters table as data processor.
//
Procedure SetParameterValueInTable(ParameterName, ParameterValue) Export
	
	TableRow = ParametersSettingsTable.Find(ParameterName, "Name");
	
	If TableRow <> Undefined Then
		
		TableRow.Value = ParameterValue;	
		
	EndIf;
	
EndProcedure

// Initializes parameters with default values from exchange rules.
//
// Parameters:
//  No.
// 
Procedure InitializeInitialParameterValues() Export
	
	For Each CurParameter IN Parameters Do
		
		SetParameterValueInTable(CurParameter.Key, CurParameter.Value);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CLEARING RULES DATA PROCESSOR

Procedure RunDeleteObject(Object, Properties, DeleteDirectly)
	
	TypeName = Properties.TypeName;
	
	If TypeName = "InformationRegister" Then
		
		Object.Delete();
		
	Else
		
		If (TypeName = "Catalog"
			Or TypeName = "ChartOfCharacteristicTypes"
			Or TypeName = "ChartOfAccounts"
			Or TypeName = "ChartOfCalculationTypes")
			AND Object.Predefined Then
			
			Return;
			
		EndIf;
		
		If DeleteDirectly Then
			
			Object.Delete();
			
		Else
			
			SetObjectDeletionMark(Object, True, Properties.TypeName);
			
		EndIf;
			
	EndIf;	
	
EndProcedure

// Deletes (or marks for deletion) selection object according to the specified rule.
//
// Parameters:
//  Object         - deleted (marked for deletion) selection object.
//  Rule        - ref to data clearing rule.
//  Properties       - metadata object property of the deleted object.
//  IncomingData - custom helper data.
// 
Procedure DeletionOfSelectionObject(Object, Rule, Properties=Undefined, IncomingData=Undefined) Export

	Cancel			       = False;
	DeleteDirectly = Rule.Directly;


	// Handler BeforeSelectionObjectDeletion
	If Not IsBlankString(Rule.BeforeDelete) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeDelete"));
				
			Else
				
				Execute(Rule.BeforeDelete);
				
			EndIf;
			
		Except
			
			WriteInformationAboutDataClearHandlerError(29, ErrorDescription(), Rule.Name, Object, "BeforeSelectionObjectDeletion");
									
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
			
	EndIf;	 


	Try
		
		RunDeleteObject(Object, Properties, DeleteDirectly);
					
	Except
		
		WriteInformationAboutDataClearHandlerError(24, ErrorDescription(), Rule.Name, Object, "");
								
	EndTry;	

EndProcedure

// Clears data by the specified rule.
//
// Parameters:
//  Rule        - ref to data clearing rule.
// 
Procedure ClearDataByRule(Rule)
	
	// Handler BeforeDataProcessor

	Cancel			= False;
	DataSelection	= Undefined;

	OutgoingData	= Undefined;


	// Handler BeforeClearingRuleDataProcessor
	If Not IsBlankString(Rule.BeforeProcess) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteInformationAboutDataClearHandlerError(27, ErrorDescription(), Rule.Name, "", "BeforeProcessClearingRule");
						
		EndTry;
		
		If Cancel Then
		
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection
	
	Properties = Managers[Rule.SelectionObject];
	
	If Rule.DataSelectionVariant = "StandardSelection" Then
		
		TypeName = Properties.TypeName;
		
		If TypeName = "AccountingRegister" 
			OR TypeName = "Constants" Then
			
			Return;
			
		EndIf;
		
		AllFieldsRequired  = Not IsBlankString(Rule.BeforeDelete);
		
		Selection = GetSelectionForDataDumpClear(Properties, TypeName, True, Rule.Directly, AllFieldsRequired);
		
		While Selection.Next() Do
			
			If TypeName =  "InformationRegister" Then
				
				RecordManager = Properties.Manager.CreateRecordManager(); 
				FillPropertyValues(RecordManager, Selection);
									
				DeletionOfSelectionObject(RecordManager, Rule, Properties, OutgoingData);
					
			Else
					
				DeletionOfSelectionObject(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
					
			EndIf;
				
		EndDo;
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then
		
		If DataSelection <> Undefined Then
			
			Selection = GetSelectionForDumpByArbitraryAlgorithm(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
										
					If TypeName =  "InformationRegister" Then
				
						RecordManager = Properties.Manager.CreateRecordManager(); 
						FillPropertyValues(RecordManager, Selection);
											
						DeletionOfSelectionObject(RecordManager, Rule, Properties, OutgoingData);				
											
					Else
							
						DeletionOfSelectionObject(Selection.Ref.GetObject(), Rule, Properties, OutgoingData);
							
					EndIf;					
					
				EndDo;	
				
			Else
				
				For Each Object IN DataSelection Do
					
					DeletionOfSelectionObject(Object.GetObject(), Rule, Properties, OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf; 
			
	EndIf; 

	
	// Handler AfterClearingRuleDataProcessor

	If Not IsBlankString(Rule.AfterProcessing) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcessing"));
				
			Else
				
				Execute(Rule.AfterProcessing);
				
			EndIf;
			
		Except
			
			WriteInformationAboutDataClearHandlerError(28, ErrorDescription(), Rule.Name, "", "AfterProcessClearingRule");
									
		EndTry;
		
	EndIf;
	
EndProcedure

// Skips data clearing rules tree and executes clearing.
//
// Parameters:
//  Rows         - Values tree strings collection.
// 
Procedure ProcessClearRules(Rows)
	
	For Each ClearingRule IN Rows Do
		
		If ClearingRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 

		If ClearingRule.IsFolder Then
			
			ProcessClearRules(ClearingRule.Rows);
			Continue;
			
		EndIf;
		
		ClearDataByRule(ClearingRule);
		
	EndDo; 
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// DATA UPLOAD PROCEDURE

// Sets a value of the Import parameter for a property of the DataExchange object.
//
// Parameters:
//  Object   - object, for which the property is set.
//  Value - value of the set property Import.
// 
Procedure SetDataExchangeImport(Object, Value = True) Export
	
	If Not ImportDataInExchangeMode Then
		Return;
	EndIf;
	
	Try
		Object.DataExchange.Load = Value;
	Except
		// Not all the objects in the exchange have the DataExchange property.
	EndTry;
	
EndProcedure

Function SetNewObjectRef(Object, Manager, SearchProperties)
	
	UI = SearchProperties["{UUID}"];
	
	If UI <> Undefined Then
		
		NewRef = Manager.GetRef(New UUID(UI));
		
		Object.SetNewObjectRef(NewRef);
		
		SearchProperties.Delete("{UUID}");
		
	Else
		
		NewRef = Undefined;
		
	EndIf;
	
	Return NewRef;
	
EndFunction

// Searches for object by the number in the list of already imported objects.
//
// Parameters:
//  NPP          - number of searched object in the exchange file.
//
// Returns:
//  Ref to the found object. If object is not found, Undefined is returned.
// 
Function FindObjectByNumber(NPP, MainObjectSearchMode = False)

	If NPP = 0 Then
		Return Undefined;
	EndIf;
	
	ResultStructure = ImportedObjects[NPP];
	
	If ResultStructure = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode AND ResultStructure.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure.ObjectReference;
	EndIf; 

EndFunction

Function FindObjectByGlobalNumber(NPP, MainObjectSearchMode = False)

	ResultStructure = ImportedGlobalObjects[NPP];
	
	If ResultStructure = Undefined Then
		Return Undefined;
	EndIf;
	
	If MainObjectSearchMode AND ResultStructure.DummyRef Then
		Return Undefined;
	Else
		Return ResultStructure.ObjectReference;
	EndIf;
	
EndFunction

Procedure WriteObjectToIB(Object, Type)
		
	Try
		
		SetDataExchangeImport(Object);
		Object.Write();
		
	Except
		
		ErrorMessageString = WriteInformationAboutErrorToProtocol(26, ErrorDescription(), Object, Type);
		
		If Not DebugModeFlag Then
			Raise ErrorMessageString;
		EndIf;
		
	EndTry;
	
EndProcedure

// Creates a new object of the
// specified type, sets attributes specified in the SearchProperties structure.
//
// Parameters:
//  Type            - type of created object.
//  SearchProperties - Structure containing set attributes of a new object.
//
// Returns:
//  New infobase object.
// 
Function CreateNewObject(Type, SearchProperties, Object = Undefined, 
	WriteObjectImmediatelyAfterCreation = True, RegisterRecordSet = Undefined,
	NewRef = Undefined, NPP = 0, GNPP = 0, ObjectParameters = Undefined,
	SetAllObjectSearchProperties = True)

	MDProperties      = Managers[Type];
	TypeName         = MDProperties.TypeName;
	Manager        = MDProperties.Manager;
	DeletionMark = Undefined;

	If TypeName = "Catalog"
		OR TypeName = "ChartOfCharacteristicTypes" Then
		
		IsFolder = SearchProperties["IsFolder"];
		
		If IsFolder = True Then
			
			Object = Manager.CreateFolder();
						
		Else
			
			Object = Manager.CreateItem();
			
		EndIf;		
				
	ElsIf TypeName = "Document" Then
		
		Object = Manager.CreateDocument();
				
	ElsIf TypeName = "ChartOfAccounts" Then
		
		Object = Manager.CreateAccount();
				
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		
		Object = Manager.CreateCalculationType();
				
	ElsIf TypeName = "InformationRegister" Then
		
		If WriteRegistersViaRecordSets Then
			
			RegisterRecordSet = Manager.CreateRecordSet();
			Object = RegisterRecordSet.Add();
			
		Else
			
			Object = Manager.CreateRecordManager();
						
		EndIf;
		
		Return Object;
		
	ElsIf TypeName = "ExchangePlan" Then
		
		Object = Manager.CreateNode();
				
	ElsIf TypeName = "Task" Then
		
		Object = Manager.CreateTask();
		
	ElsIf TypeName = "BusinessProcess" Then
		
		Object = Manager.CreateBusinessProcess();	
		
	ElsIf TypeName = "Enum" Then
		
		Object = MDProperties.EmptyRef;	
		Return Object;
		
	ElsIf TypeName = "BusinessProcessRoutePoint" Then
		
		Return Undefined;
				
	EndIf;
	
	NewRef = SetNewObjectRef(Object, Manager, SearchProperties);
	
	If SetAllObjectSearchProperties Then
		SetObjectSearchAttributes(Object, SearchProperties, , False, False);
	EndIf;
	
	// Checks
	If TypeName = "Document"
		OR TypeName = "Task"
		OR TypeName = "BusinessProcess" Then
		
		If Not ValueIsFilled(Object.Date) Then
			
			Object.Date = CurrentSessionDate();
			
		EndIf;
		
	EndIf;
		
	// If Owner is not set, then you
	// should add field to the possible search fields and specify fields without Owner in the SEARCHFIELDS event if the search by it is unnecessary.
	
	If WriteObjectImmediatelyAfterCreation Then
		
		If Not ImportObjectsByRefWithoutDeletionMark Then
			Object.DeletionMark = True;
		EndIf;
		
		If GNPP <> 0
			OR Not OptimizedObjectWriting Then
		
			WriteObjectToIB(Object, Type);
			
		Else
			
			// Do not write object at once but only remember what
			// you should write save this information to the special
			// objects stack for writing return both a new ref, and the object although it is not written.
			If NewRef = Undefined Then
				
				// Generate a new reference on your own.
				NewUUID = New UUID;
				NewRef = Manager.GetRef(NewUUID);
				Object.SetNewObjectRef(NewRef);
				
			EndIf;			
			
			SupplementNotRecordedObjectsStack(NPP, GNPP, Object, NewRef, Type, ObjectParameters);
			
			Return NewRef;
			
		EndIf;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Object.Ref;
	
EndFunction

// Reads object property node from file, sets property value.
//
// Parameters:
//  Type            - property value type.
//  ObjectFound   - if after you execute function - False,
//                   then property object is not found in the infobase and a new one will be created.
//
// Returns:
//  Property value
// 
Function ReadProperty(Type, OCRName = "")
	
	Value = Undefined;
	PropertyExistence = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Value" Then
			
			SearchByProperty = deAttribute(ExchangeFile, deStringType, "Property");
			Value         = deItemValue(ExchangeFile, Type, SearchByProperty, CutRowsFromRight);
			PropertyExistence = True;
			
		ElsIf NodeName = "Ref" Then
			
			Value       = FindObjectByRef(Type, OCRName);
			PropertyExistence = True;
			
		ElsIf NodeName = "NPP" Then
			
			deIgnore(ExchangeFile);
			
		ElsIf NodeName = "GSn" Then
			
			ExchangeFile.Read();
			GNPP = Number(ExchangeFile.Value);
			If GNPP <> 0 Then
				Value  = FindObjectByGlobalNumber(GNPP);
				PropertyExistence = True;
			EndIf;
			
			ExchangeFile.Read();
			
		ElsIf (NodeName = "Property" OR NodeName = "ParameterValue") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			If Not PropertyExistence
				AND ValueIsFilled(Type) Then
				
				// If there is nothing - , then there is an empty value.
				Value = deGetBlankValue(Type);
				
			EndIf;
			
			Break;
			
		ElsIf NodeName = "Expression" Then
			
			Value = Eval(deItemValue(ExchangeFile, deStringType, , False));
			PropertyExistence = True;
			
		ElsIf NodeName = "Empty" Then
			
			Value = deGetBlankValue(Type);
			PropertyExistence = True;		
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Value;	
	
EndFunction

Function SetObjectSearchAttributes(FoundObject, SearchProperties, SearchPropertiesDontReplace, 
	ShouldCompareWithCurrentAttributes = True, DontReplacePropertiesNotToChange = True)
	
	ObjectAttributeChanged = False;
				
	For Each Property IN SearchProperties Do
					
		Name      = Property.Key;
		Value = Property.Value;
		
		If DontReplacePropertiesNotToChange
			AND SearchPropertiesDontReplace[Name] <> Undefined Then
			
			Continue;
			
		EndIf;
					
		If Name = "IsFolder" 
			OR Name = "{UUID}" 
			OR Name = "{PredefinedItemName}" Then
						
			Continue;
						
		ElsIf Name = "DeletionMark" Then
						
			If Not ShouldCompareWithCurrentAttributes
				OR FoundObject.DeletionMark <> Value Then
							
				FoundObject.DeletionMark = Value;
				ObjectAttributeChanged = True;
							
			EndIf;
						
		Else
				
			// Set different attributes.
			If FoundObject[Name] <> NULL Then
			
				If Not ShouldCompareWithCurrentAttributes
					OR FoundObject[Name] <> Value Then
						
					FoundObject[Name] = Value;
					ObjectAttributeChanged = True;
						
				EndIf;
				
			EndIf;
				
		EndIf;
					
	EndDo;
	
	Return ObjectAttributeChanged;
	
EndFunction

Function FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
	ObjectTypeName, SearchProperty, SearchPropertyValue, ObjectFound,
	CreateNewItemIfNotFound, FoundOrCreatedObject,
	MainObjectSearchMode, ObjectPropertyModified, NPP, GNPP,
	ObjectParameters, NewUUIDRef = Undefined)
	
	IsEnum = PropertyStructure.TypeName = "Enum";
	
	If IsEnum Then
		
		SearchString = "";
		
	Else
		
		SearchString = PropertyStructure.SearchString;
		
	EndIf;
	
	If MainObjectSearchMode Or IsBlankString(SearchString) Then
		SearchByUUIDQueryString = "";
	Else
		SearchByUUIDQueryString = SearchByUUIDQueryString;
	EndIf;
	
	Object = FindObjectByProperty(PropertyStructure.Manager, SearchProperty, SearchPropertyValue,
		FoundOrCreatedObject, , , SearchByUUIDQueryString);
		
	ObjectFound = Not (Object = Undefined OR Object.IsEmpty());
		
	If Not ObjectFound Then
		If CreateNewItemIfNotFound Then
		
			Object = CreateNewObject(ObjectType, SearchProperties, FoundOrCreatedObject, 
				Not MainObjectSearchMode,,NewUUIDRef, NPP, GNPP, ObjectParameters);
				
			ObjectPropertyModified = True;
		EndIf;
		Return Object;
	
	EndIf;
	
	If IsEnum Then
		Return Object;
	EndIf;			
	
	If MainObjectSearchMode Then
		
		If FoundOrCreatedObject = Undefined Then
			FoundOrCreatedObject = Object.GetObject();
		EndIf;
			
		ObjectPropertyModified = SetObjectSearchAttributes(FoundOrCreatedObject, SearchProperties, SearchPropertiesDontReplace);
				
	EndIf;
		
	Return Object;
	
EndFunction

Function GetPropertyType()
	
	PropertyTypeString = deAttribute(ExchangeFile, deStringType, "Type");
	If IsBlankString(PropertyTypeString) Then
		Return Undefined;
	EndIf;
	
	Return Type(PropertyTypeString);
	
EndFunction

Function GetPropertyTypeByAdditionalInformation(TypeInformation, PropertyName)
	
	PropertyType = GetPropertyType();
				
	If PropertyType = Undefined
		AND TypeInformation <> Undefined Then
		
		PropertyType = TypeInformation[PropertyName];
		
	EndIf;
	
	Return PropertyType;
	
EndFunction

Procedure ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	SearchByEqualDate = False;
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
					
			IsParameter = (NodeName = "ParameterValue");
			
			Name = deAttribute(ExchangeFile, deStringType, "Name");
			
			If Name = "{UUID}" 
				OR Name = "{PredefinedItemName}" Then
				
				PropertyType = deStringType;
				
			Else
			
				PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
			
			EndIf;
			
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "Donotreplace");
			SearchByEqualDate = SearchByEqualDate 
					OR deAttribute(ExchangeFile, deBooleanType, "SearchByEqualDate");
			//
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			PropertyValue = ReadProperty(PropertyType, OCRName);
			
			If (Name = "IsFolder") AND (PropertyValue <> True) Then
				
				PropertyValue = False;
												
			EndIf;
			
			If IsParameter Then
				
				
				AddParameterIfNeeded(ObjectParameters, Name, PropertyValue);
				
			Else
			
				SearchProperties[Name] = PropertyValue;
				
				If DontReplaceProperty Then
					
					SearchPropertiesDontReplace[Name] = True;
					
				EndIf;
				
			EndIf;
			
		ElsIf (NodeName = "Ref") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Function DefineFieldHasUnlimitedLength(TypeManager, ParameterName)
	
	LongStrings = Undefined;
	If Not TypeManager.Property("LongStrings", LongStrings) Then
		
		LongStrings = New Map;
		For Each Attribute IN TypeManager.MDObject.Attributes Do
			
			If Attribute.Type.ContainsType(deStringType) 
				AND (Attribute.Type.StringQualifiers.Length = 0) Then
				
				LongStrings.Insert(Attribute.Name, Attribute.Name);	
				
			EndIf;
			
		EndDo;
		
		TypeManager.Insert("LongStrings", LongStrings);
		
	EndIf;
	
	Return (LongStrings[ParameterName] <> Undefined);
		
EndFunction

Function DefineThisParameterIsOfUnlimitedLength(TypeManager, ParameterValue, ParameterName)
	
	Try
			
		If TypeOf(ParameterValue) = deStringType Then
			OpenEndedString = DefineFieldHasUnlimitedLength(TypeManager, ParameterName);
		Else
			OpenEndedString = False;
		EndIf;		
												
	Except
				
		OpenEndedString = False;
				
	EndTry;
	
	Return OpenEndedString;	
	
EndFunction

Function FindItemUsingQuery(PropertyStructure, SearchProperties, ObjectType = Undefined, 
	TypeManager = Undefined, RealPropertyForSearchCount = Undefined)
	
	PropertyCountForSearch = ?(RealPropertyForSearchCount = Undefined, SearchProperties.Count(), RealPropertyForSearchCount);
	
	If PropertyCountForSearch = 0
		AND PropertyStructure.TypeName = "Enum" Then
		
		Return PropertyStructure.EmptyRef;
		
	EndIf;	
	
	QueryText       = PropertyStructure.SearchString;
	
	If IsBlankString(QueryText) Then
		Return PropertyStructure.EmptyRef;
	EndIf;
	
	SearchQuery       = New Query();
	PropertyUsedInSearchCount = 0;
			
	For Each Property IN SearchProperties Do
				
		ParameterName      = Property.Key;
		
		// You can search not by all parameters.
		If ParameterName = "{UUID}"
			OR ParameterName = "{PredefinedItemName}" Then
						
			Continue;
						
		EndIf;
		
		ParameterValue = Property.Value;
		SearchQuery.SetParameter(ParameterName, ParameterValue);
				
		Try
			
			OpenEndedString = DefineThisParameterIsOfUnlimitedLength(PropertyStructure, ParameterValue, ParameterName);		
													
		Except
					
			OpenEndedString = False;
					
		EndTry;
		
		PropertyUsedInSearchCount = PropertyUsedInSearchCount + 1;
				
		If OpenEndedString Then
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " LIKE &" + ParameterName;
					
		Else
					
			QueryText = QueryText + ?(PropertyUsedInSearchCount > 1, " AND ", "") + ParameterName + " = &" + ParameterName;
					
		EndIf;
								
	EndDo;
	
	If PropertyUsedInSearchCount = 0 Then
		Return Undefined;
	EndIf;
	
	SearchQuery.Text = QueryText;
	Result = SearchQuery.Execute();
			
	If Result.IsEmpty() Then
		
		Return Undefined;
								
	Else
		
		// Return first found object.
		Selection = Result.Select();
		Selection.Next();
		ObjectReference = Selection.Ref;
				
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Function DefineByObjectTypeUseAdditionalSearchBySearchFields(RefTypeAsString)
	
	MapValue = mExtendedSearchParameterMap.Get(RefTypeAsString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item IN Rules Do
			
			If Item.Value.Receiver = RefTypeAsString Then
				
				If Item.Value.SynchronizeByID = True Then
					
					MustContinueSearch = (Item.Value.SearchBySearchFieldsIfNotFoundByID = True);
					mExtendedSearchParameterMap.Insert(RefTypeAsString, MustContinueSearch);
					
					Return MustContinueSearch;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mExtendedSearchParameterMap.Insert(RefTypeAsString, False);
		Return False;
	
	Except
		
		mExtendedSearchParameterMap.Insert(RefTypeAsString, False);
		Return False;
	
    EndTry;
	
EndFunction

// Determines object conversion rule (OCR) by the receiver object type.
// 
// Parameters:
//  RefTypeAsString - String - object type in a string presentation, for example, CatalogRef.ProductsAndServices.
// 
// Returns:
//  MatchValue = Object conversion rule.
// 
Function GetConversionRuleWithSearchAlgorithmByTargetObjectType(RefTypeAsString)
	
	MapValue = mConversionRuleMap.Get(RefTypeAsString);
	
	If MapValue <> Undefined Then
		Return MapValue;
	EndIf;
	
	Try
	
		For Each Item IN Rules Do
			
			If Item.Value.Receiver = RefTypeAsString Then
				
				If Item.Value.HasSearchFieldSequenceHandler = True Then
					
					Rule = Item.Value;
					
					mConversionRuleMap.Insert(RefTypeAsString, Rule);
					
					Return Rule;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		mConversionRuleMap.Insert(RefTypeAsString, Undefined);
		Return Undefined;
	
	Except
		
		mConversionRuleMap.Insert(RefTypeAsString, Undefined);
		Return Undefined;
	
	EndTry;
	
EndFunction

Function FindLinkToObjectByOneProperty(SearchProperties, PropertyStructure)
	
	For Each Property IN SearchProperties Do
					
		ParameterName      = Property.Key;
					
		// You can search not by all parameters.
		If ParameterName = "{UUID}"
			OR ParameterName = "{PredefinedItemName}" Then
						
			Continue;
						
		EndIf;
					
		ParameterValue = Property.Value;
		ObjectReference = FindObjectByProperty(PropertyStructure.Manager, ParameterName, ParameterValue, Undefined, PropertyStructure, SearchProperties);
		
	EndDo;
	
	Return ObjectReference;
	
EndFunction

Function FindLinkToDocument(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate)
	
	// Try to find document by date and number.
	SearchWithQuery = SearchByEqualDate OR (RealPropertyForSearchCount <> 2);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	DocumentNumber = SearchProperties["Number"];
	DocumentDate  = SearchProperties["Date"];
					
	If (DocumentNumber <> Undefined) AND (DocumentDate <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(DocumentNumber, DocumentDate);
																		
	Else
						
		// Failed to find by date and number - it is required to search by query.
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Function FindLinkToCatalog(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Owner     = SearchProperties["Owner"];
	Parent     = SearchProperties["Parent"];
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
				
	Quantity          = 0;
				
	If Owner <> Undefined Then	Quantity = 1 + Quantity; EndIf;
	If Parent <> Undefined Then	Quantity = 1 + Quantity; EndIf;
	If Code <> Undefined Then Quantity = 1 + Quantity; EndIf;
	If Description <> Undefined Then	Quantity = 1 + Quantity; EndIf;
				
	SearchWithQuery = (Quantity <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByCode(Code, , Parent, Owner);
																		
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, TRUE, Parent, Owner);
											
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindLinkToCCT(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Parent     = SearchProperties["Parent"];
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Quantity          = 0;
				
	If Parent     <> Undefined Then	Quantity = 1 + Quantity EndIf;
	If Code          <> Undefined Then Quantity = 1 + Quantity EndIf;
	If Description <> Undefined Then	Quantity = 1 + Quantity EndIf;
				
	SearchWithQuery = (Quantity <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByCode(Code, Parent);
												
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, TRUE, Parent);
																	
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
			
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindLinkToExchangePlan(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Code"];
	Description = SearchProperties["Description"];
	Quantity          = 0;
				
	If Code          <> Undefined Then Quantity = 1 + Quantity EndIf;
	If Description <> Undefined Then	Quantity = 1 + Quantity EndIf;
				
	SearchWithQuery = (Quantity <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If     (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByCode(Code);
												
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, TRUE);
																	
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindLinkToTask(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Description = SearchProperties["Description"];
	Quantity          = 0;
				
	If Code          <> Undefined Then Quantity = 1 + Quantity EndIf;
	If Description <> Undefined Then	Quantity = 1 + Quantity EndIf;
				
	SearchWithQuery = (Quantity <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
	
					
	If     (Code <> Undefined) AND (Description = Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(Code);
												
	ElsIf (Code = Undefined) AND (Description <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByDescription(Description, TRUE);
																	
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Function FindLinkToBusinessProcess(SearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery)
	
	Code          = SearchProperties["Number"];
	Quantity          = 0;
				
	If Code <> Undefined Then Quantity = 1 + Quantity EndIf;
								
	SearchWithQuery = (Quantity <> RealPropertyForSearchCount);
				
	If SearchWithQuery Then
		Return Undefined;
	EndIf;
					
	If  (Code <> Undefined) Then
						
		ObjectReference = PropertyStructure.Manager.FindByNumber(Code);
												
	Else
						
		SearchWithQuery = True;
		ObjectReference = Undefined;
						
	EndIf;
															
	Return ObjectReference;
	
EndFunction

Procedure AddLinkToListOfImportedObjects(GNPPRefs, RefNPP, ObjectReference, DummyRef = False)
	
	// Remember reference to object.
	If Not RememberImportedObjects 
		OR ObjectReference = Undefined Then
		
		Return;
		
	EndIf;
	
	RecordStructure = New Structure("ObjectRef, DummyRef", ObjectReference, DummyRef);
	
	// Remember reference to object.
	If GNPPRefs <> 0 Then
		
		ImportedGlobalObjects[GNPPRefs] = RecordStructure;
		
	ElsIf RefNPP <> 0 Then
		
		ImportedObjects[RefNPP] = RecordStructure;
						
	EndIf;	
	
EndProcedure

Function FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, 
	PropertyStructure, Stringofsearchpropertynames, SearchByEqualDate)
	
	// It is not required to search by the predefined item name and
	// by a unique ref to object, it is required to search only by those properties that are available in the property names string. If it is empty
	// there, then by all available search properties.
		
	SearchWithQuery = False;	
	
	If IsBlankString(Stringofsearchpropertynames) Then
		
		TemporarySearchProperties = SearchProperties;
		
	Else
		
		ResultingStringForParsing = StrReplace(Stringofsearchpropertynames, " ", "");
		StringLength = StrLen(ResultingStringForParsing);
		If Mid(ResultingStringForParsing, StringLength, 1) <> "," Then
			
			ResultingStringForParsing = ResultingStringForParsing + ",";
			
		EndIf;
		
		TemporarySearchProperties = New Map;
		For Each PropertyItem IN SearchProperties Do
			
			ParameterName = PropertyItem.Key;
			If Find(ResultingStringForParsing, ParameterName + ",") > 0 Then
				
				TemporarySearchProperties.Insert(ParameterName, PropertyItem.Value); 	
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UUIDProperty = TemporarySearchProperties["{UUID}"];
	PredefinedNameProperty = TemporarySearchProperties["{PredefinedItemName}"];
	
	RealPropertyForSearchCount = TemporarySearchProperties.Count();
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(UUIDProperty <> Undefined, 1, 0);
	RealPropertyForSearchCount = RealPropertyForSearchCount - ?(PredefinedNameProperty <> Undefined, 1, 0);
	
	
	If RealPropertyForSearchCount = 1 Then
				
		ObjectReference = FindLinkToObjectByOneProperty(TemporarySearchProperties, PropertyStructure);
																						
	ElsIf ObjectTypeName = "Document" Then
				
		ObjectReference = FindLinkToDocument(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery, SearchByEqualDate);
											
	ElsIf ObjectTypeName = "Catalog" Then
				
		ObjectReference = FindLinkToCatalog(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
								
	ElsIf ObjectTypeName = "ChartOfCharacteristicTypes" Then
				
		ObjectReference = FindLinkToCCT(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "ExchangePlan" Then
				
		ObjectReference = FindLinkToExchangePlan(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
							
	ElsIf ObjectTypeName = "Task" Then
				
		ObjectReference = FindLinkToTask(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
												
	ElsIf ObjectTypeName = "BusinessProcess" Then
				
		ObjectReference = FindLinkToBusinessProcess(TemporarySearchProperties, PropertyStructure, RealPropertyForSearchCount, SearchWithQuery);
									
	Else
				
		SearchWithQuery = True;
				
	EndIf;
		
	If SearchWithQuery Then
			
		ObjectReference = FindItemUsingQuery(PropertyStructure, TemporarySearchProperties, ObjectType, , RealPropertyForSearchCount);
				
	EndIf;
	
	Return ObjectReference;
	
EndFunction

Procedure ProcessObjectSearchPropertiesSetup(SetAllObjectSearchProperties, ObjectType, SearchProperties, 
	SearchPropertiesDontReplace, ObjectReference, CreatedObject, WriteNewObjectToInfobase = True, ObjectAttributeChanged = False)
	
	If SetAllObjectSearchProperties <> True Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return;
	EndIf;
	
	If CreatedObject = Undefined Then
		CreatedObject = ObjectReference.GetObject();
	EndIf;
	
	ObjectAttributeChanged = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
	
	// If something is changed, then rewrite the object.
	If ObjectAttributeChanged
		AND WriteNewObjectToInfobase Then
		
		WriteObjectToIB(CreatedObject, ObjectType);
		
	EndIf;
	
EndProcedure

Function ProcessObjectSearchByStructure(ObjectNumber, ObjectType, CreatedObject,
	MainObjectSearchMode, ObjectPropertyModified, ObjectFound,
	IsGlobalNumber, ObjectParameters)
	
	DataStructure = mNotWrittenObjectGlobalStack[ObjectNumber];
	
	If DataStructure <> Undefined Then
		
		ObjectPropertyModified = True;
		CreatedObject = DataStructure.Object;
		
		If DataStructure.KnownRef = Undefined Then
			
			SetLinkForObject(DataStructure);
			
		EndIf;
			
		ObjectReference = DataStructure.KnownRef;
		ObjectParameters = DataStructure.ObjectParameters;
		
		ObjectFound = False;
		
	Else
		
		CreatedObject = Undefined;
		
		If IsGlobalNumber Then
			ObjectReference = FindObjectByGlobalNumber(ObjectNumber, MainObjectSearchMode);
		Else
			ObjectReference = FindObjectByNumber(ObjectNumber, MainObjectSearchMode);
		EndIf;
		
	EndIf;
	
	If ObjectReference <> Undefined Then
		
		If MainObjectSearchMode Then
			
			SearchProperties = "";
			SearchPropertiesDontReplace = "";
			ReadInformationAboutSearchProperties(ObjectType, SearchProperties, SearchPropertiesDontReplace, , ObjectParameters);
			
			// For the main search you should check search fields again, they may need to be reset...
			If CreatedObject = Undefined Then
				
				CreatedObject = ObjectReference.GetObject();
				
			EndIf;
			
			ObjectPropertyModified = SetObjectSearchAttributes(CreatedObject, SearchProperties, SearchPropertiesDontReplace);
			
		Else
			
			deIgnore(ExchangeFile);
			
		EndIf;
		
		Return ObjectReference;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure ReadInformationAboutSearchProperties(ObjectType, SearchProperties, SearchPropertiesDontReplace, 
	SearchByEqualDate = False, ObjectParameters = Undefined)
	
	If SearchProperties = "" Then
		SearchProperties = New Map;		
	EndIf;
	
	If SearchPropertiesDontReplace = "" Then
		SearchPropertiesDontReplace = New Map;		
	EndIf;	
	
	TypeInformation = mDataTypeMapForImport[ObjectType];
	ReadSearchPropertiesFromFile(SearchProperties, SearchPropertiesDontReplace, TypeInformation, SearchByEqualDate, ObjectParameters);	
	
EndProcedure

// Searches object in the infobase if it is not found, creates a new one.
//
// Parameters:
//  ObjectType     - searched object type.
//  SearchProperties - Structure containing properties according to which object is searched.
//  ObjectFound   - if False, then object is not found and the new one is created.
//
// Returns:
//  New or found infobase object.
//  
Function FindObjectByRef(ObjectType,
							OCRName = "",
							SearchProperties = "", 
							SearchPropertiesDontReplace = "", 
							ObjectFound = True, 
							CreatedObject = Undefined, 
							DontCreateObjectIfNotFound = Undefined,
							MainObjectSearchMode = False, 
							ObjectPropertyModified = False,
							GlobalRefNPP = 0,
							RefNPP = 0,
							KnownUUIDRef = Undefined,
							ObjectParameters = Undefined)

							
	SearchByEqualDate = False;
	ObjectReference = Undefined;
	PropertyStructure = Undefined;
	ObjectTypeName = Undefined;
	IsDocumentObject = False;
	DummyObjectRef = False;
	OCR = Undefined;
	SearchAlgorithm = "";
	
	If RememberImportedObjects Then
		
		// There is a number by order from file - so search by it.
		GlobalRefNPP = deAttribute(ExchangeFile, deNumberType, "GSn");
		
		If GlobalRefNPP <> 0 Then
			
			ObjectReference = ProcessObjectSearchByStructure(GlobalRefNPP, ObjectType, CreatedObject,
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, True, ObjectParameters);
			
			If ObjectReference <> Undefined Then
				Return ObjectReference;
			EndIf;
			
		EndIf;
		
		// There is a number by order from file - so search by it.
		RefNPP = deAttribute(ExchangeFile, deNumberType, "NPP");
		
		If RefNPP <> 0 Then
		
			ObjectReference = ProcessObjectSearchByStructure(RefNPP, ObjectType, CreatedObject,
				MainObjectSearchMode, ObjectPropertyModified, ObjectFound, False, ObjectParameters);
				
			If ObjectReference <> Undefined Then
				Return ObjectReference;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	DontCreateObjectIfNotFound = deAttribute(ExchangeFile, deBooleanType, "DoNotCreateIfNotFound");
	OnExchangeObjectByRefSetGIUDOnly = Not MainObjectSearchMode 
		AND deAttribute(ExchangeFile, deBooleanType, "OnExchangeObjectByRefSetGIUDOnly");
	
	// Create objects search properties.
	ReadInformationAboutSearchProperties(ObjectType, SearchProperties, SearchPropertiesDontReplace, SearchByEqualDate, ObjectParameters);
		
	CreatedObject = Undefined;
	
	If Not ObjectFound Then
		
		ObjectReference = CreateNewObject(ObjectType, SearchProperties, CreatedObject, , , , RefNPP, GlobalRefNPP);
		AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, ObjectReference);
		Return ObjectReference;
		
	EndIf;	
		
	PropertyStructure   = Managers[ObjectType];
	ObjectTypeName     = PropertyStructure.TypeName;
		
	UUIDProperty = SearchProperties["{UUID}"];
	PredefinedNameProperty = SearchProperties["{PredefinedItemName}"];
	
	OnExchangeObjectByRefSetGIUDOnly = OnExchangeObjectByRefSetGIUDOnly
		AND UUIDProperty <> Undefined;
		
	// If this is a predefined item, search by name.
	If PredefinedNameProperty <> Undefined Then
		
		CreateNewObjectAutomatically = Not DontCreateObjectIfNotFound
			AND Not OnExchangeObjectByRefSetGIUDOnly;
		
		ObjectReference = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{PredefinedItemName}", PredefinedNameProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, MainObjectSearchMode, ObjectPropertyModified,
			RefNPP, GlobalRefNPP, ObjectParameters);
			
	ElsIf (UUIDProperty <> Undefined) Then
			
		// You should not always create a new item by a unique ID, you may need to continue searching.
		MustContinueSearchIfItemNotFoundByGUID = DefineByObjectTypeUseAdditionalSearchBySearchFields(PropertyStructure.RefTypeAsString);
		
		CreateNewObjectAutomatically = (NOT DontCreateObjectIfNotFound
			AND Not MustContinueSearchIfItemNotFoundByGUID)
			AND Not OnExchangeObjectByRefSetGIUDOnly;
			
		ObjectReference = FindOrCreateObjectByProperty(PropertyStructure, ObjectType, SearchProperties, SearchPropertiesDontReplace,
			ObjectTypeName, "{UUID}", UUIDProperty, ObjectFound, 
			CreateNewObjectAutomatically, CreatedObject, 
			MainObjectSearchMode, ObjectPropertyModified,
			RefNPP, GlobalRefNPP, ObjectParameters, KnownUUIDRef);
			
		If Not MustContinueSearchIfItemNotFoundByGUID Then

			If Not ValueIsFilled(ObjectReference)
				AND OnExchangeObjectByRefSetGIUDOnly Then
				
				ObjectReference = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));
				ObjectFound = False;
				DummyObjectRef = True;
			
			EndIf;
			
			If ObjectReference <> Undefined 
				AND ObjectReference.IsEmpty() Then
						
				ObjectReference = Undefined;
						
			EndIf;
			
			If ObjectReference <> Undefined
				OR CreatedObject <> Undefined Then

				AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, ObjectReference, DummyObjectRef);
				
			EndIf;
			
			Return ObjectReference;	
			
		EndIf;
		
	EndIf;
		
	If ObjectReference <> Undefined 
		AND ObjectReference.IsEmpty() Then
		
		ObjectReference = Undefined;
		
	EndIf;
		
	// ObjectRef is not found yet.
	If ObjectReference <> Undefined
		OR CreatedObject <> Undefined Then
		
		AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, ObjectReference);
		Return ObjectReference;
		
	EndIf;
	
	Variantsearchnumber = 1;
	Stringofsearchpropertynames = "";
	PreviousSearchString = Undefined;
	StopSearch = False;
	SetAllObjectSearchProperties = True;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If OCR = Undefined Then
		
		OCR = GetConversionRuleWithSearchAlgorithmByTargetObjectType(PropertyStructure.RefTypeAsString);
		
	EndIf;
	
	If OCR <> Undefined Then
		
		SearchAlgorithm = OCR.SearchFieldSequence;
		
	EndIf;
	
	HasSearchAlgorithm = Not IsBlankString(SearchAlgorithm);
	
	While Variantsearchnumber <= 10
		AND HasSearchAlgorithm Do
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "SearchFieldSequence"));
					
			Else
				
				Execute(SearchAlgorithm);
			
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(73, ErrorDescription(), "", "",
				ObjectType, Undefined, NStr("en='Search fields sequence';ru='Последовательность полей поиска'"));
			
		EndTry;
		
		DontSearch = StopSearch = True 
			OR Stringofsearchpropertynames = PreviousSearchString
			OR ValueIsFilled(ObjectReference);
		
		If Not DontSearch Then
		
			// the search itself
			ObjectReference = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
				Stringofsearchpropertynames, SearchByEqualDate);
				
			DontSearch = ValueIsFilled(ObjectReference);
			
			If ObjectReference <> Undefined
				AND ObjectReference.IsEmpty() Then
				ObjectReference = Undefined;
			EndIf;
			
		EndIf;
			
		If DontSearch Then
			
			If MainObjectSearchMode AND SetAllObjectSearchProperties = True Then
				
				ProcessObjectSearchPropertiesSetup(SetAllObjectSearchProperties, ObjectType, SearchProperties, SearchPropertiesDontReplace,
					ObjectReference, CreatedObject, Not MainObjectSearchMode, ObjectPropertyModified);
				
			EndIf;
			
			Break;
			
		EndIf;
		
		Variantsearchnumber = Variantsearchnumber + 1;
		PreviousSearchString = Stringofsearchpropertynames;
		
	EndDo;
	
	If Not HasSearchAlgorithm Then
		
		// Search itself without the search algorithm.
		ObjectReference = FindItemBySearchProperties(ObjectType, ObjectTypeName, SearchProperties, PropertyStructure, 
					Stringofsearchpropertynames, SearchByEqualDate);
		
	EndIf;
	
	ObjectFound = ValueIsFilled(ObjectReference);
	
	If MainObjectSearchMode
		AND ValueIsFilled(ObjectReference)
		AND (ObjectTypeName = "Document" 
		OR ObjectTypeName = "Task"
		OR ObjectTypeName = "BusinessProcess") Then
		
		// If document has date in the search properties - , then set it.
		EmptyDate = Not ValueIsFilled(SearchProperties["Date"]);
		CanReplace = (NOT EmptyDate) 
			AND (SearchPropertiesDontReplace["Date"] = Undefined);
			
		If CanReplace Then
			
			If CreatedObject = Undefined Then
				CreatedObject = ObjectReference.GetObject();
			EndIf;
			
			CreatedObject.Date = SearchProperties["Date"];
			
		EndIf;
		
	EndIf;
	
	// You do not have to always create new object.
	If Not ValueIsFilled(ObjectReference)
		AND CreatedObject = Undefined Then 
		
		If OnExchangeObjectByRefSetGIUDOnly Then
			
			ObjectReference = PropertyStructure.Manager.GetRef(New UUID(UUIDProperty));	
			DummyObjectRef = True;
			
		ElsIf Not DontCreateObjectIfNotFound Then
		
			ObjectReference = CreateNewObject(ObjectType, SearchProperties, CreatedObject, Not MainObjectSearchMode, , KnownUUIDRef, RefNPP, 
				GlobalRefNPP, ,SetAllObjectSearchProperties);
				
			ObjectPropertyModified = True;
				
		EndIf;
			
		ObjectFound = False;
		
	Else
		
		ObjectFound = ValueIsFilled(ObjectReference);
		
	EndIf;
	
	If ObjectReference <> Undefined
		AND ObjectReference.IsEmpty() Then
		
		ObjectReference = Undefined;
		
	EndIf;
	
	AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, ObjectReference, DummyObjectRef);
		
	Return ObjectReference;
	
EndFunction

// Sets objects properties (record).
//
// Parameters:
//  Record         - object which properties you should set.
//                   For example, tabular section row and register record.
//
Procedure SetRecordProperties(Object, Record, TypeInformation,
	ObjectParameters, BranchName, SearchDataInTS, TSCopyForSearch, RecNo)
	
	MustSearchInTS = (SearchDataInTS <> Undefined)
								AND (TSCopyForSearch <> Undefined)
								AND TSCopyForSearch.Count() <> 0;
								
	If MustSearchInTS Then
		
		PropertyReadingStructure = New Structure();
		ExtDimensionReadingStructure = New Structure();
		
	EndIf;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameter = (NodeName = "ParameterValue");
			
			Name    = deAttribute(ExchangeFile, deStringType, "Name");
			OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Name = "RecordType" AND Find(Metadata.FindByType(TypeOf(Record)).FullName(), "AccumulationRegister") Then
				
				PropertyType = deAccumulationRecordTypeType;
				
			Else
				
				PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
				
			EndIf;
			
			PropertyValue = ReadProperty(PropertyType, OCRName);
			
			If IsParameter Then
				AddComplexParameterIfNeeded(ObjectParameters, BranchName, RecNo, Name, PropertyValue);			
			ElsIf MustSearchInTS Then 
				PropertyReadingStructure.Insert(Name, PropertyValue);	
			Else
				
				Try
					
					Record[Name] = PropertyValue;
					
				Except
					
					LR = GetProtocolRecordStructure(26, ErrorDescription());
					LR.OCRName           = OCRName;
					LR.Object           = Object;
					LR.ObjectType       = TypeOf(Object);
					LR.Property         = String(Record) + "." + Name;
					LR.Value         = PropertyValue;
					LR.ValueType      = TypeOf(PropertyValue);
					ErrorMessageString = WriteInExecutionProtocol(26, LR, True);
					
					If Not DebugModeFlag Then
						Raise ErrorMessageString;
					EndIf;
				EndTry;
				
			EndIf;
			
		ElsIf NodeName = "ExtDimensionDr" OR NodeName = "ExtDimensionCr" Then
			
			// Search by extra dimension is not implemented.
			
			Key = Undefined;
			Value = Undefined;
			
			While ExchangeFile.Read() Do
				
				NodeName = ExchangeFile.LocalName;
								
				If NodeName = "Property" Then
					
					Name    = deAttribute(ExchangeFile, deStringType, "Name");
					OCRName = deAttribute(ExchangeFile, deStringType, "OCRName");
					PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
										
					If Name = "Key" Then
						
						Key = ReadProperty(PropertyType);
						
					ElsIf Name = "Value" Then
						
						Value = ReadProperty(PropertyType, OCRName);
						
					EndIf;
					
				ElsIf (NodeName = "ExtDimensionDr" OR NodeName = "ExtDimensionCr") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
					
					Break;
					
				Else
					
					WriteInExecutionProtocol(9);
					Break;
					
				EndIf;
				
			EndDo;
			
			If Key <> Undefined 
				AND Value <> Undefined Then
				
				If Not MustSearchInTS Then
				
					Record[NodeName][Key] = Value;
					
				Else
					
					RecordMapping = Undefined;
					If Not ExtDimensionReadingStructure.Property(NodeName, RecordMapping) Then
						RecordMapping = New Map;
						ExtDimensionReadingStructure.Insert(NodeName, RecordMapping);
					EndIf;
					
					RecordMapping.Insert(Key, Value);
					
				EndIf;
				
			EndIf;
				
		ElsIf (NodeName = "Record") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	If MustSearchInTS Then
		
		SearchStructure = New Structure();
		
		For Each SearchItem IN  SearchDataInTS.TSSearchFields Do
			
			ItemValue = Undefined;
			PropertyReadingStructure.Property(SearchItem, ItemValue);
			
			SearchStructure.Insert(SearchItem, ItemValue);		
			
		EndDo;		
		
		SearchResultArray = TSCopyForSearch.FindRows(SearchStructure);
		
		RecordFound = SearchResultArray.Count() > 0;
		If RecordFound Then
			FillPropertyValues(Record, SearchResultArray[0]);
		EndIf;
		
		// Over filling with properties and extra dimension value.
		For Each KeyAndValue IN PropertyReadingStructure Do
			
			Record[KeyAndValue.Key] = KeyAndValue.Value;
			
		EndDo;
		
		For Each ElementName IN ExtDimensionReadingStructure Do
			
			For Each ItemKey IN ElementName.Value Do
			
				Record[ElementName.Key][ItemKey.Key] = ItemKey.Value;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Imports object tabular section.
//
// Parameters:
//  Object         - object tabular section of which should be imported.
//  Name            - tabular section name.
//  Clear       - if it is True, then tabular section is cleared before that.
// 
Procedure ImportTabularSection(Object, Name, Clear, DocumentTypeCommonInformation, MustWriteObject, 
	ObjectParameters, Rule)

	TabularSectionName = Name + "TabularSection";
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[TabularSectionName];
	Else
	    TypeInformation = Undefined;
	EndIf;
			
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("TabularSection." + Name, "ItemName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	CWT = Object[Name];

	If Clear
		AND CWT.Count() <> 0 Then
		
		MustWriteObject = True;
		
		If SearchDataInTS <> Undefined Then
			TSCopyForSearch = CWT.Unload();
		EndIf;
		CWT.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = CWT.Unload();
		
	EndIf;
	
	RecNo = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "Record" Then
			Try
				
				MustWriteObject = True;
				Record = CWT.Add();
				
			Except
				Record = Undefined;
			EndTry;
			
			If Record = Undefined Then
				deIgnore(ExchangeFile);
			Else
				SetRecordProperties(Object, Record, TypeInformation, ObjectParameters, TabularSectionName, SearchDataInTS, TSCopyForSearch, RecNo);
			EndIf;
			
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "TabularSection") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure 

// Imports object movement
//
// Parameters:
//  Object         - object movements of which should be imported.
//  Name            - register name.
//  Clear       - if True, then movements are cleared beforehand.
// 
Procedure ImportRegisterRecords(Object, Name, Clear, DocumentTypeCommonInformation, MustWriteObject, 
	ObjectParameters, Rule)
	
	RegisterRecordName = Name + "RecordSet";
	If DocumentTypeCommonInformation <> Undefined Then
		TypeInformation = DocumentTypeCommonInformation[RegisterRecordName];
	Else
	    TypeInformation = Undefined;
	EndIf;
	
	SearchDataInTS = Undefined;
	If Rule <> Undefined Then
		SearchDataInTS = Rule.SearchInTabularSections.Find("RecordSet." + Name, "ItemName");
	EndIf;
	
	TSCopyForSearch = Undefined;
	
	RegisterRecords = Object.RegisterRecords[Name];
	RegisterRecords.Write = True;
	
	If RegisterRecords.Count()=0 Then
		RegisterRecords.Read();
	EndIf;
	
	If Clear
		AND RegisterRecords.Count() <> 0 Then
		
		MustWriteObject = True;
		
		If SearchDataInTS <> Undefined Then 
			TSCopyForSearch = RegisterRecords.Unload();
		EndIf;
		
        RegisterRecords.Clear();
		
	ElsIf SearchDataInTS <> Undefined Then
		
		TSCopyForSearch = RegisterRecords.Unload();	
		
	EndIf;
	
	RecNo = 0;
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
			
		If NodeName = "Record" Then
			
			Record = RegisterRecords.Add();
			MustWriteObject = True;
			SetRecordProperties(Object, Record, TypeInformation, ObjectParameters, RegisterRecordName, SearchDataInTS, TSCopyForSearch, RecNo);
			RecNo = RecNo + 1;
			
		ElsIf (NodeName = "RecordSet") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Imports object of the TypeDescription type from the specified xml-source.
//
// Parameters:
//  Source         - xml-source.
// 
Function ImportObjectTypes(Source)
	
	// DateQualifiers
	
	DateContent =  deAttribute(Source, deStringType,  "DateContent");
	
	// StringQualifiers
	
	Length           =  deAttribute(Source, deNumberType,  "Length");
	AllowedLength =  deAttribute(Source, deStringType, "AllowedLength");
	
	// NumberQualifiers
	
	Digits             = deAttribute(Source, deNumberType,  "Digits");
	FractionDigits = deAttribute(Source, deNumberType,  "FractionDigits");
	AllowedFlag          = deAttribute(Source, deStringType, "AllowedSign");
	
	// Read types array
	
	TypeArray = New Array;
	
	While Source.Read() Do
		NodeName = Source.LocalName;
		
		If      NodeName = "Type" Then
			TypeArray.Add(Type(deItemValue(Source, deStringType)));
		ElsIf (NodeName = "Types") AND ( Source.NodeType = odNodeTypeXML_EndElement) Then
			Break;
		Else
			WriteInExecutionProtocol(9);
			Break;
		EndIf;
		
	EndDo;
	
	If TypeArray.Count() > 0 Then
		
		// DateQualifiers
		
		If DateContent = "Date" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Date);
		ElsIf DateContent = "DateTime" Then
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		ElsIf DateContent = "Time" Then
			DateQualifiers   = New DateQualifiers(DateFractions.Time);
		Else
			DateQualifiers   = New DateQualifiers(DateFractions.DateTime);
		EndIf;
		
		// NumberQualifiers
		
		If Digits > 0 Then
			If AllowedFlag = "Nonnegative" Then
				Mark = AllowedSign.Nonnegative;
			Else
				Mark = AllowedSign.Any;
			EndIf; 
			NumberQualifiers  = New NumberQualifiers(Digits, FractionDigits, Mark);
		Else
			NumberQualifiers  = New NumberQualifiers();
		EndIf;
		
		// StringQualifiers
		
		If Length > 0 Then
			If AllowedLength = "Fixed" Then
				AllowedLength = AllowedLength.Fixed;
			Else
				AllowedLength = AllowedLength.Variable;
			EndIf;
			StringQualifiers = New StringQualifiers(Length, AllowedLength);
		Else
			StringQualifiers = New StringQualifiers();
		EndIf;
		
		Return New TypeDescription(TypeArray, NumberQualifiers, StringQualifiers, DateQualifiers);
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure SetObjectDeletionMark(Object, DeletionMark, ObjectTypeName)
	
	If (DeletionMark = Undefined)
		AND (Object.DeletionMark <> True) Then
		
		Return;
		
	EndIf;
	
	MarkToSet = ?(DeletionMark <> Undefined, DeletionMark, False);
	
	SetDataExchangeImport(Object);
		
	// For hierarchical objects mark as deleted only a specific object.
	If ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ChartOfAccounts" Then
			
		Object.SetDeletionMark(MarkToSet, False);
			
	Else	
		
		Object.SetDeletionMark(MarkToSet);
		
	EndIf;
	
EndProcedure

Procedure WriteDocumentInSafeMode(Document, ObjectType)
	
	If Document.Posted Then
						
		Document.Posted = False;
			
	EndIf;		
								
	WriteObjectToIB(Document, ObjectType);
	
EndProcedure

Function GetObjectByRefAndAddInformation(CreatedObject, Ref)
	
	// If object is created, then work with it if you find it, - receive object.
	If CreatedObject <> Undefined Then
		Object = CreatedObject;
	Else
		If Ref.IsEmpty() Then
			Object = Undefined;
		Else
			Object = Ref.GetObject();
		EndIf;		
	EndIf;
	
	Return Object;
	
EndFunction

Procedure CommentsToObjectImport(NPP, Rulename, Source, ObjectType, GNPP = 0)
	
	If CommentObjectProcessingFlag Then
		
		If NPP <> 0 Then
			MessageString = PlaceParametersIntoString(NStr("en='Import object No %1';ru='Загрузка объекта № %1'"), NPP);
		Else
			MessageString = PlaceParametersIntoString(NStr("en='Import object No %1';ru='Загрузка объекта № %1'"), GNPP);
		EndIf;
		
		LR = GetProtocolRecordStructure();
		
		If Not IsBlankString(Rulename) Then
			
			LR.OCRName = Rulename;
			
		EndIf;
		
		If Not IsBlankString(Source) Then
			
			LR.Source = Source;
			
		EndIf;
		
		LR.ObjectType = ObjectType;
		WriteInExecutionProtocol(MessageString, LR, False);
		
	EndIf;	
	
EndProcedure

Procedure AddParameterIfNeeded(DataParameters, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	DataParameters.Insert(ParameterName, ParameterValue);
	
EndProcedure

Procedure AddComplexParameterIfNeeded(DataParameters, ParameterBranchName, LineNumber, ParameterName, ParameterValue)
	
	If DataParameters = Undefined Then
		DataParameters = New Map;
	EndIf;
	
	CurrentParameterData = DataParameters[ParameterBranchName];
	
	If CurrentParameterData = Undefined Then
		
		CurrentParameterData = New ValueTable;
		CurrentParameterData.Columns.Add("LineNumber");
		CurrentParameterData.Columns.Add("ParameterName");
		CurrentParameterData.Indexes.Add("LineNumber");
		
		DataParameters.Insert(ParameterBranchName, CurrentParameterData);	
		
	EndIf;
	
	If CurrentParameterData.Columns.Find(ParameterName) = Undefined Then
		CurrentParameterData.Columns.Add(ParameterName);
	EndIf;		
	
	RowData = CurrentParameterData.Find(LineNumber, "LineNumber");
	If RowData = Undefined Then
		RowData = CurrentParameterData.Add();
		RowData.LineNumber = LineNumber;
	EndIf;		
	
	RowData[ParameterName] = ParameterValue;
	
EndProcedure

Procedure SetLinkForObject(NOTWrittenObjectStackRow)
	
	// Object is not written yet but it is referenced.
	ObjectToWrite = NotWrittenObjectStackRow.Object;
	
	MDProperties      = Managers[NotWrittenObjectStackRow.ObjectType];
	Manager        = MDProperties.Manager;
		
	NewUUID = New UUID;
	NewRef = Manager.GetRef(NewUUID);
		
	ObjectToWrite.SetNewObjectRef(NewRef);
	NotWrittenObjectStackRow.KnownRef = NewRef;
	
EndProcedure

Procedure SupplementNotRecordedObjectsStack(NPP, GNPP, Object, KnownRef, ObjectType, ObjectParameters)
	
	NumberForStack = ?(NPP = 0, GNPP, NPP);
	
	StackString = mNotWrittenObjectGlobalStack[NumberForStack];
	If StackString <> Undefined Then
		Return;
	EndIf;
	
	mNotWrittenObjectGlobalStack.Insert(NumberForStack, New Structure("Object, KnownRef, ObjectType, ObjectParameters", Object, KnownRef, ObjectType, ObjectParameters));
	
EndProcedure

Procedure DeleteFromStackOfNotRecordedObjects(NPP, GNPP)
	
	NumberForStack = ?(NPP = 0, GNPP, NPP);
	mNotWrittenObjectGlobalStack.Delete(NumberForStack);	
	
EndProcedure

Procedure WriteNotRecordedObjects()
	
	For Each DataRow IN mNotWrittenObjectGlobalStack Do
		
		// deferred object record
		Object = DataRow.Value.Object;
		RefNPP = DataRow.Key;
		
		WriteObjectToIB(Object, DataRow.Value.ObjectType);
		
		AddLinkToListOfImportedObjects(0, RefNPP, Object.Ref);
				
	EndDo;
	
	mNotWrittenObjectGlobalStack.Clear();
	
EndProcedure

Procedure DoNumberCodeGenerationIfNeeded(Generatenewnumberorcodeifnotspecified, Object, ObjectTypeName, MustWriteObject, 
	DataExchangeMode)
	
	If Not Generatenewnumberorcodeifnotspecified
		OR Not DataExchangeMode Then
		
		// If number should not be generated or not in the data exchange mode, then do nothing... platform
		// will generate everything itself.
		Return;
	EndIf;
	
	// Look if quantity or number is filled by type of document.
	If ObjectTypeName = "Document"
		OR ObjectTypeName =  "BusinessProcess"
		OR ObjectTypeName = "Task" Then
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			MustWriteObject = True;
			
		EndIf;
		
	ElsIf ObjectTypeName = "Catalog"
		OR ObjectTypeName = "ChartOfCharacteristicTypes"
		OR ObjectTypeName = "ExchangePlan" Then
		
		If Not ValueIsFilled(Object.Code) Then
			
			Object.SetNewCode();
			MustWriteObject = True;
			
		EndIf;	
		
	EndIf;
	
EndProcedure

// Reads another object from exchange file, executes import.
//
// Parameters:
//  No.
// 
Function ReadObject()

	NPP						= deAttribute(ExchangeFile, deNumberType,  "NPP");
	GNPP					= deAttribute(ExchangeFile, deNumberType,  "GSn");
	Source				= deAttribute(ExchangeFile, deStringType, "Source");
	Rulename				= deAttribute(ExchangeFile, deStringType, "Rulename");
	Donotreplaceobject 		= deAttribute(ExchangeFile, deBooleanType, "Donotreplace");
	AutonumerationPrefix	= deAttribute(ExchangeFile, deStringType, "AutonumerationPrefix");
	ObjectTypeAsString       = deAttribute(ExchangeFile, deStringType, "Type");
	ObjectType 				= Type(ObjectTypeAsString);
	TypeInformation = mDataTypeMapForImport[ObjectType];

	CommentsToObjectImport(NPP, Rulename, Source, ObjectType, GNPP);    
	
	PropertyStructure = Managers[ObjectType];
	ObjectTypeName   = PropertyStructure.TypeName;

	If ObjectTypeName = "Document" Then
		
		WriteMode     = deAttribute(ExchangeFile, deStringType, "WriteMode");
		PostingMode = deAttribute(ExchangeFile, deStringType, "PostingMode");
		
	EndIf;	
	
	Ref          = Undefined;
	Object          = Undefined;
	ObjectFound    = True;
	DeletionMark = Undefined;
	
	SearchProperties  = New Map;
	SearchPropertiesDontReplace  = New Map;
	
	MustWriteObject = Not WriteToInformationBaseChangedObjectsOnly;
	


	If Not IsBlankString(Rulename) Then
		
		Rule = Rules[Rulename];
		HasBeforeImportHandler = Rule.HasBeforeImportHandler;
		HasOnImportHandler    = Rule.HasOnImportHandler;
		HasAfterImportHandler  = Rule.HasAfterImportHandler;
		Generatenewnumberorcodeifnotspecified = Rule.Generatenewnumberorcodeifnotspecified;
		
	Else
		
		HasBeforeImportHandler = False;
		HasOnImportHandler    = False;
		HasAfterImportHandler  = False;
		Generatenewnumberorcodeifnotspecified = False;
		
	EndIf;


    // global handler of the BeforeObjectImport event.
	If HasBeforeObjectImportGlobalHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeObjectImport"));
				
			Else
				
				Execute(Conversion.BeforeObjectImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(53, ErrorDescription(), Rulename, Source,
				ObjectType, Undefined, NStr("en='BeforeObjectImport(Global)';ru='ПередЗагрузкойОбъекта (глобальный)'"));
							
		EndTry;
						
		If Cancel Then	//	Denial of the object import
			
			deIgnore(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	
    // Event handler BeforeObjectImport.
	If HasBeforeImportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeImport"));
				
			Else
				
				Execute(Rule.BeforeImport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutOCRHandlerErrorImport(19, ErrorDescription(), Rulename, Source,
				ObjectType, Undefined, "BeforeObjectImport");
			
		EndTry;
		
		If Cancel Then // Denial of the object import
			
			deIgnore(ExchangeFile, "Object");
			Return Undefined;
			
		EndIf;
		
	EndIf;
	
	ObjectPropertyModified = False;
	RecordSet = Undefined;
	GlobalRefNPP = 0;
	RefNPP = 0;
	ObjectParameters = Undefined;
		
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
				
		If NodeName = "Property"
			OR NodeName = "ParameterValue" Then
			
			IsParameterForObject = (NodeName = "ParameterValue");
			
			If Not IsParameterForObject
				AND Object = Undefined Then
				
				// Object was not found or not created - try to do it now.
				ObjectFound = False;

			    // Event handler OnObjectImport.
				If HasOnImportHandler Then
					
					// If there is a handler during the import, then object should be rewritten as there may be changes.
					MustWriteObjectEarlier = MustWriteObject;
      				ObjectModified = True;
										
					Try
						
						If HandlersDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
						
						EndIf;
						MustWriteObject = ObjectModified OR MustWriteObjectEarlier;
						
					Except
						
						WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source,
							ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;

				// This way you could not create object in event - , create it separately.
				If Object = Undefined Then
					
					MustWriteObject = True;
					
					If ObjectTypeName = "Constants" Then
						
						Object = Constants.CreateSet();
						Object.Read();
						
					Else
						
						CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefNPP, GlobalRefNPP, ObjectParameters);
												
					EndIf;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "Donotreplace");
			OCRName             = deAttribute(ExchangeFile, deStringType, "OCRName");
			
			If Not IsParameterForObject
				AND ((ObjectFound AND DontReplaceProperty) 
				OR (Name = "IsFolder")
				OR (Object[Name] = NULL)) Then
				
				// unknown property
				deIgnore(ExchangeFile, NodeName);
				Continue;
				
			EndIf; 

			
			// Read and set value property
			PropertyType = GetPropertyTypeByAdditionalInformation(TypeInformation, Name);
			Value    = ReadProperty(PropertyType, OCRName);
			
			If IsParameterForObject Then
				
				// Expand object parameters collection.
				AddParameterIfNeeded(ObjectParameters, Name, Value);
				
			Else
			
				If Name = "DeletionMark" Then
					
					DeletionMark = Value;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						MustWriteObject = True;
					EndIf;
										
				Else
					
					Try
						
						If Not MustWriteObject Then
							
							MustWriteObject = (Object[Name] <> Value);
							
						EndIf;
						
						Object[Name] = Value;
						
					Except
						
						LR = GetProtocolRecordStructure(26, ErrorDescription());
						LR.OCRName           = Rulename;
						LR.NPP              = NPP;
						LR.GNPP             = GNPP;
						LR.Source         = Source;
						LR.Object           = Object;
						LR.ObjectType       = ObjectType;
						LR.Property         = Name;
						LR.Value         = Value;
						LR.ValueType      = TypeOf(Value);
						ErrorMessageString = WriteInExecutionProtocol(26, LR, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;					
									
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "Ref" Then
			
			// Item reference - first, get object by reference and then set properties.
			CreatedObject = Undefined;
			DontCreateObjectIfNotFound = Undefined;
			KnownUUIDRef = Undefined;
			
			Ref = FindObjectByRef(ObjectType,
								Rulename, 
								SearchProperties,
								SearchPropertiesDontReplace,
								ObjectFound,
								CreatedObject,
								DontCreateObjectIfNotFound,
								True,
								ObjectPropertyModified,
								GlobalRefNPP,
								RefNPP,
								KnownUUIDRef,
								ObjectParameters);
			
			MustWriteObject = MustWriteObject OR ObjectPropertyModified;
			
			If Ref = Undefined
				AND DontCreateObjectIfNotFound = True Then
				
				deIgnore(ExchangeFile, "Object");
				Break;
			
			ElsIf ObjectTypeName = "Enum" Then
				
				Object = Ref;
			
			Else
				
				Object = GetObjectByRefAndAddInformation(CreatedObject, Ref);
				
				If ObjectFound AND Donotreplaceobject AND (NOT HasOnImportHandler) Then
					
					deIgnore(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
				If Ref = Undefined Then
					
					SupplementNotRecordedObjectsStack(NPP, GNPP, CreatedObject, KnownUUIDRef, ObjectType, ObjectParameters);
					
				EndIf;
							
			EndIf; 
			
		    // Event handler OnObjectImport.
			If HasOnImportHandler Then
				
				MustWriteObjectEarlier = MustWriteObject;
      			ObjectModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "OnImport"));
						
					Else
						
						Execute(Rule.OnImport);
						
					EndIf;
					
					MustWriteObject = ObjectModified OR MustWriteObjectEarlier;
					
				Except
					
					WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source, 
							ObjectType, Object, "OnImportObject");
					
				EndTry;
				
				If ObjectFound AND Donotreplaceobject Then
					
					deIgnore(ExchangeFile, "Object");
					Break;
					
				EndIf;
				
			EndIf;
			
		ElsIf NodeName = "TabularSection"
			OR NodeName = "RecordSet" Then

			If Object = Undefined Then
				
				ObjectFound = False;

			    // Event handler OnObjectImport.
				
				If HasOnImportHandler Then
					
					MustWriteObjectEarlier = MustWriteObject;
      				ObjectModified = True;
					
					Try
						
						If HandlersDebugModeFlag Then
							
							Execute(GetHandlerCallString(Rule, "OnImport"));
							
						Else
							
							Execute(Rule.OnImport);
							
						EndIf;
						
						MustWriteObject = ObjectModified OR MustWriteObjectEarlier;
						
					Except
						
						WriteInformationAboutOCRHandlerErrorImport(20, ErrorDescription(), Rulename, Source, 
							ObjectType, Object, "OnImportObject");
						
					EndTry;
					
				EndIf;
				
			EndIf;
			
			Name                = deAttribute(ExchangeFile, deStringType, "Name");
			DontReplaceProperty = deAttribute(ExchangeFile, deBooleanType, "Donotreplace");
			Donotclear          = deAttribute(ExchangeFile, deBooleanType, "Donotclear");

			If ObjectFound AND DontReplaceProperty Then
				
				deIgnore(ExchangeFile, NodeName);
				Continue;
				
			EndIf;
			
			If Object = Undefined Then
					
				CreateNewObject(ObjectType, SearchProperties, Object, False, RecordSet, , RefNPP, GlobalRefNPP, ObjectParameters);
				MustWriteObject = True;
									
			EndIf;
			
			If NodeName = "TabularSection" Then
				
				// Import items from tabular section.
				ImportTabularSection(Object, Name, Not Donotclear, TypeInformation, MustWriteObject, ObjectParameters, Rule);
				
			ElsIf NodeName = "RecordSet" Then
				
				// import movements
				ImportRegisterRecords(Object, Name, Not Donotclear, TypeInformation, MustWriteObject, ObjectParameters, Rule);
				
			EndIf;			
			
		ElsIf (NodeName = "Object") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			Cancel = False;
			
		    // Global handler of the AfterObjectImport event.
			If HasAftertObjectImportGlobalHandler Then
				
				MustWriteObjectEarlier = MustWriteObject;
      			ObjectModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Conversion, "AftertObjectImport"));
						
					Else
						
						Execute(Conversion.AftertObjectImport);
						
					EndIf;
					
					MustWriteObject = ObjectModified OR MustWriteObjectEarlier;
					
				Except
					
					WriteInformationAboutOCRHandlerErrorImport(54, ErrorDescription(), Rulename, Source,
							ObjectType, Object, NStr("en='AftertObjectImport(Global)';ru='ПослеЗагрузкиОбъекта (глобальный)'"));
					
				EndTry;
				
			EndIf;
			
			// Event handler AfterObjectImport.
			If HasAfterImportHandler Then
				
				MustWriteObjectEarlier = MustWriteObject;
				ObjectModified = True;
				
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(Rule, "AfterImport"));
						
					Else
						
						Execute(Rule.AfterImport);
				
					EndIf;
					
					MustWriteObject = ObjectModified OR MustWriteObjectEarlier;
					
				Except
					
					WriteInformationAboutOCRHandlerErrorImport(21, ErrorDescription(), Rulename, Source,
							ObjectType, Object, "AftertObjectImport");
						
				EndTry;
				
			EndIf;
			
			If Cancel Then
				
				AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, Undefined);
				DeleteFromStackOfNotRecordedObjects(NPP, GNPP);
				Return Undefined;
				
			EndIf;
			
			If ObjectTypeName = "Document" Then
				
				If WriteMode = "Posting" Then
					
					WriteMode = DocumentWriteMode.Posting;
					
				Else
					
					WriteMode = ?(WriteMode = "UndoPosting", DocumentWriteMode.UndoPosting, DocumentWriteMode.Write);
					
				EndIf;
				
				
				PostingMode = ?(PostingMode = "RealTime", DocumentPostingMode.RealTime, DocumentPostingMode.Regular);
				

				// If you want to post the document marked for deletion, then clear deletion mark...
				If Object.DeletionMark
					AND (WriteMode = DocumentWriteMode.Posting) Then
					
					Object.DeletionMark = False;
					MustWriteObject = True;
					
					// You should clear deletion mark anyway.
					DeletionMark = False;
									
				EndIf;				
				
				Try
					
					MustWriteObject = MustWriteObject OR (WriteMode <> DocumentWriteMode.Write);
					
					DataExchangeMode = WriteMode = DocumentWriteMode.Write;
					
					DoNumberCodeGenerationIfNeeded(Generatenewnumberorcodeifnotspecified, Object, 
						ObjectTypeName, MustWriteObject, DataExchangeMode);
					
					If MustWriteObject Then
					
						SetDataExchangeImport(Object, DataExchangeMode);
						If Object.Posted Then
							Object.DeletionMark = False;
						EndIf;
						
						Object.Write(WriteMode, PostingMode);
						
					EndIf;					
						
				Except
						
					// Unable to execute required actions for document.
					WriteDocumentInSafeMode(Object, ObjectType);
						
						
					LR                        = GetProtocolRecordStructure(25, ErrorDescription());
					LR.OCRName                 = Rulename;
						
					If Not IsBlankString(Source) Then
							
						LR.Source           = Source;
							
					EndIf;
						
					LR.ObjectType             = ObjectType;
					LR.Object                 = String(Object);
					WriteInExecutionProtocol(25, LR);
						
				EndTry;
				
				AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, Object.Ref);
									
				DeleteFromStackOfNotRecordedObjects(NPP, GNPP);
				
			ElsIf ObjectTypeName <> "Enum" Then
				
				If ObjectTypeName = "InformationRegister" Then
					
					MustWriteObject = Not WriteToInformationBaseChangedObjectsOnly;
					
					If PropertyStructure.Periodical 
						AND Not ValueIsFilled(Object.Period) Then
						
						Object.Period = CurrentSessionDate();
						MustWriteObject = True;							
												
					EndIf;
					
					If WriteRegistersViaRecordSets Then
						
						MustCheckDataForTempSet = 
							(WriteToInformationBaseChangedObjectsOnly
								AND Not MustWriteObject) 
							OR Donotreplaceobject;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
						EndIf;
						
						// You should set filter in register.
						For Each FilterItem IN RecordSet.Filter Do
							
							FilterItem.Set(Object[FilterItem.Name]);
							If MustCheckDataForTempSet Then
								TemporaryRecordSet.Filter[FilterItem.Name].Set(Object[FilterItem.Name]);
							EndIf;
							
						EndDo;
						
						If MustCheckDataForTempSet Then
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() = 0 Then
								MustWriteObject = True;
							Else
								
								// You do not want to replace the existing set.
								If Donotreplaceobject Then
									Return Undefined;
								EndIf;
								
								MustWriteObject = False;
								NewTable = RecordSet.Unload();
								TableOld = TemporaryRecordSet.Unload(); 
								
								RowNew = NewTable[0]; 
								OldRow = TableOld[0]; 
								
								For Each TableColumn IN NewTable.Columns Do
									
									MustWriteObject = RowNew[TableColumn.Name] <>  OldRow[TableColumn.Name];
									If MustWriteObject Then
										Break;
									EndIf;
									
								EndDo;							
								
							EndIf;
							
						EndIf;
						
						Object = RecordSet;
						
					Else
						
						// Write register not as a records set.
						If Donotreplaceobject Then
							
							// You may not want to replace the existing record.
							TemporaryRecordSet = InformationRegisters[PropertyStructure.Name].CreateRecordSet();
							
							// You should set filter in register.
							For Each FilterItem IN TemporaryRecordSet.Filter Do
							
								FilterItem.Set(Object[FilterItem.Name]);
																
							EndDo;
							
							TemporaryRecordSet.Read();
							
							If TemporaryRecordSet.Count() > 0 Then
								Return Undefined;
							EndIf;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
				IsReferenceTypeObject = Not( ObjectTypeName = "InformationRegister"
					OR ObjectTypeName = "Constants");
					
				If IsReferenceTypeObject Then 	
					
					DoNumberCodeGenerationIfNeeded(Generatenewnumberorcodeifnotspecified, Object, ObjectTypeName, MustWriteObject, ImportDataInExchangeMode);
					
					If DeletionMark = Undefined Then
						DeletionMark = False;
					EndIf;
					
					If Object.DeletionMark <> DeletionMark Then
						Object.DeletionMark = DeletionMark;
						MustWriteObject = True;
					EndIf;
					
				EndIf;
				
				// Direct writing of the object itself.
				If MustWriteObject Then
				
					WriteObjectToIB(Object, ObjectType);
					
				EndIf;
				
				If IsReferenceTypeObject Then
					
					AddLinkToListOfImportedObjects(GlobalRefNPP, RefNPP, Object.Ref);
					
				EndIf;
				
				DeleteFromStackOfNotRecordedObjects(NPP, GNPP);
								
			EndIf;
			
			Break;
			
		ElsIf NodeName = "SequenceRecordSet" Then
			
			deIgnore(ExchangeFile);
			
		ElsIf NodeName = "Types" Then

			If Object = Undefined Then
				
				ObjectFound = False;
				Ref       = CreateNewObject(ObjectType, SearchProperties, Object, , , , RefNPP, GlobalRefNPP, ObjectParameters);
								
			EndIf; 

			ObjectTypeDescription = ImportObjectTypes(ExchangeFile);

			If ObjectTypeDescription <> Undefined Then
				
				Object.ValueType = ObjectTypeDescription;
				
			EndIf; 
			
		Else
			
			WriteInExecutionProtocol(9);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Object;

EndFunction


////////////////////////////////////////////////////////////////////////////////
// DATA EXPORT PROCEDURE BY EXCHANGE RULES

Function GetDocumentRecordSet(DocumentRef, SourceKind, RegisterName)
	
	If SourceKind = "AccumulationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "InformationRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = InformationRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "AccountingRegisterRecordSet" Then
		
		DocumentRegisterRecordSet = AccountingRegisters[RegisterName].CreateRecordSet();
		
	ElsIf SourceKind = "CalculationRegisterRecordSet" Then	
		
		DocumentRegisterRecordSet = CalculationRegisters[RegisterName].CreateRecordSet();
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	DocumentRegisterRecordSet.Filter.Recorder.Set(DocumentRef);
	DocumentRegisterRecordSet.Read();
	
	Return DocumentRegisterRecordSet;
	
EndFunction


Procedure ExecuteStructureRecordToXML(DataStructure, PropertyCollectionNode)
	
	PropertyCollectionNode.WriteStartElement("Property");
	
	For Each CollectionItem IN DataStructure Do
		
		If CollectionItem.Key = "Expression"
			OR CollectionItem.Key = "Value"
			OR CollectionItem.Key = "NPP"
			OR CollectionItem.Key = "GSn" Then
			
			deWriteItem(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		ElsIf CollectionItem.Key = "Ref" Then
			
			PropertyCollectionNode.WriteRaw(CollectionItem.Value);
			
		Else
			
			SetAttribute(PropertyCollectionNode, CollectionItem.Key, CollectionItem.Value);
			
		EndIf;
		
	EndDo;
	
	PropertyCollectionNode.WriteEndElement();		
	
EndProcedure

Procedure CreateObjectsForRecordingDataToXML(DataStructure, Propirtiesnode, XMLNodeRequired, NodeName, XMLNodeDescription = "Property")
	
	If XMLNodeRequired Then
		
		Propirtiesnode = CreateNode(XMLNodeDescription);
		SetAttribute(Propirtiesnode, "Name", NodeName);
		
	Else
		
		DataStructure = New Structure("Name", NodeName);	
		
	EndIf;		
	
EndProcedure

Procedure AddAttributeForRecordToXML(PropertyNodeStructure, Propirtiesnode, AttributeName, AttributeValue)
	
	If PropertyNodeStructure <> Undefined Then
		PropertyNodeStructure.Insert(AttributeName, AttributeValue);
	Else
		SetAttribute(Propirtiesnode, AttributeName, AttributeValue);
	EndIf;
	
EndProcedure

Procedure WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, Propirtiesnode)
	
	If PropertyNodeStructure <> Undefined Then
		ExecuteStructureRecordToXML(PropertyNodeStructure, PropertyCollectionNode);
	Else
		AddSubordinate(PropertyCollectionNode, Propirtiesnode);
	EndIf;
	
EndProcedure



// Generates receiver object property nodes according to the specified properties conversion rules collection.
//
// Parameters:
//  Source		     - custom data source.
//  Receiver		     - receiver object xml-node.
//  IncomingData	     - custom helper data passed
//                         to rule for conversion execution.
//  OutgoingData      - custom helper data passed
//                         to property objects conversion rules.
//  OCR				     - ref to object conversion rule (parent of the properties conversion rules collection).
//  PGCR                 - ref to properties group conversion rule.
//  PropertyCollectionNode - properties collection xml-node.
// 
Procedure DumpGroupOfProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR, PropertyCollectionNode, 
	ExportRefOnly, TempFileList = Undefined)
	
	ObjectsCollection = Undefined;
	Donotreplace        = PGCR.Donotreplace;
	Donotclear         = False;
	ExportGroupToFile = PGCR.ExportGroupToFile;
	
	// Handler BeforeDataExportProcessor
	If PGCR.HasBeforeProcessExportHandler Then
		
		Cancel = False;
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "BeforeProcessExport"));
				
			Else
				
				Execute(PGCR.BeforeProcessExport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorPCRHandlers(48, ErrorDescription(), OCR, PGCR,
				Source, "BeforePropertyGroupExport",, False);
		
		EndTry;
		
		If Cancel Then // Denial of the properties group data processor.
			
			Return;
			
		EndIf;
		
	EndIf;

	
    TargetKind = PGCR.TargetKind;
	SourceKind = PGCR.SourceKind;
	
	
    // Creating a node of subordinate object collection.
	PropertyNodeStructure = Undefined;
	ObjectCollectionNode = Undefined;
	MasterNodeName = "";
	
	If TargetKind = "TabularSection" Then
		
		MasterNodeName = "TabularSection";
		
		CreateObjectsForRecordingDataToXML(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Receiver, MasterNodeName);
		
		If Donotreplace Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotreplace", "true");
						
		EndIf;
		
		If Donotclear Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotclear", "true");
						
		EndIf;
		
	ElsIf TargetKind = "SubordinateCatalog" Then
				
		
	ElsIf TargetKind = "SequenceRecordSet" Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForRecordingDataToXML(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Receiver, MasterNodeName);
		
	ElsIf Find(TargetKind, "RegisterRecordSet") > 0 Then
		
		MasterNodeName = "RecordSet";
		
		CreateObjectsForRecordingDataToXML(PropertyNodeStructure, ObjectCollectionNode, TRUE, PGCR.Receiver, MasterNodeName);
		
		If Donotreplace Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotreplace", "true");
						
		EndIf;
		
		If Donotclear Then
			
			AddAttributeForRecordToXML(PropertyNodeStructure, ObjectCollectionNode, "Donotclear", "true");
						
		EndIf;
		
	Else  // this is a simple grouping
		
		DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		     PropertyCollectionNode, , , OCR.DontExportPropertyObjectsByRefs OR ExportRefOnly);
			
		If PGCR.HasAfterProcessExportHandler Then
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
					
				Else
					
					Execute(PGCR.AfterProcessExport);
			
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(49, ErrorDescription(), OCR, PGCR,
					Source, "AfterProcessPropertyGroupExport",, False);
				
			EndTry;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	// Receive subordinate objects collection.
	
	If ObjectsCollection <> Undefined Then
		
		// Initialized collection in the BeforeDataProcessor handler.
		
	ElsIf PGCR.GetFromIncomingData Then
		
		Try
			
			ObjectsCollection = IncomingData[PGCR.Receiver];
			
			If TypeOf(ObjectsCollection) = Type("QueryResult") Then
				
				ObjectsCollection = ObjectsCollection.Unload();
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorPCRHandlers(66, ErrorDescription(), OCR, PGCR, Source,,,False);
			
			Return;
		EndTry;
		
	ElsIf SourceKind = "TabularSection" Then
		
		ObjectsCollection = Source[PGCR.Source];
		
		If TypeOf(ObjectsCollection) = Type("QueryResult") Then
			
			ObjectsCollection = ObjectsCollection.Unload();
			
		EndIf;
		
	ElsIf SourceKind = "SubordinateCatalog" Then
		
	ElsIf Find(SourceKind, "RegisterRecordSet") > 0 Then
		
		ObjectsCollection = GetDocumentRecordSet(Source, SourceKind, PGCR.Source);
				
	ElsIf IsBlankString(PGCR.Source) Then
		
		ObjectsCollection = Source[PGCR.Receiver];
		
		If TypeOf(ObjectsCollection) = Type("QueryResult") Then
			
			ObjectsCollection = ObjectsCollection.Unload();
			
		EndIf;
		
	EndIf;
	
	ExportGroupToFile = ExportGroupToFile OR (ObjectsCollection.Count() > 1000);
	ExportGroupToFile = ExportGroupToFile AND (DirectReadInRecipientInfobase = False);
	
	If ExportGroupToFile Then
		
		PGCR.XMLNodeRequiredOnExport = False;
		
		If TempFileList = Undefined Then
			TempFileList = New ValueList();
		EndIf;
		
		RecordFileName = GetTempFileName();
		TempFileList.Add(RecordFileName);
		
		TempRecordFile = New TextWriter;
		Try
			
			TempRecordFile.Open(RecordFileName, TextEncoding.UTF8);
			
		Except
			
			WriteInformationAboutErrorConversionHandlers(1000, ErrorDescription(), NStr("en='Error when creating the temp file for the data export';ru='Ошибка при создании временного файла для выгрузки данных'"));
			
		EndTry; 
		
		InformationToWriteToFile = ObjectCollectionNode.Close();
		TempRecordFile.WriteLine(InformationToWriteToFile);
		
	EndIf;
	
	For Each CollectionObject IN ObjectsCollection Do
		
		// Handler BeforeExport
		If PGCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "BeforeExport"));
					
				Else
					
					Execute(PGCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(50, ErrorDescription(), OCR, PGCR,
					Source, "BeforePropertiesGroupExport",, False);
				
				Break;
				
			EndTry;
			
			If Cancel Then	//	Denial of the subordinate object export.
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		// Handler OnExport
		
		If PGCR.XMLNodeRequiredOnExport OR ExportGroupToFile Then
			CollectionObjectNode = CreateNode("Record");
		Else
			ObjectCollectionNode.WriteStartElement("Record");
			CollectionObjectNode = ObjectCollectionNode;
		EndIf;
		
		StandardProcessing	= True;
		
		If PGCR.HasOnExportHandler Then
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "OnExport"));
					
				Else
					
					Execute(PGCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(51, ErrorDescription(), OCR, PGCR,
					Source, "OnExportingGroupsProperties",, False);
				
				Break;
				
			EndTry;
			
		EndIf;

		//	Export collection object properties.
		
		If StandardProcessing Then
			
			If PGCR.GroupRules.Count() > 0 Then
				
		 		DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PGCR.GroupRules, 
		 			CollectionObjectNode, CollectionObject, , OCR.DontExportPropertyObjectsByRefs OR ExportRefOnly);
				
			EndIf;
			
		EndIf;
		
		// Handler AfterExport
		
		If PGCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PGCR, "AfterExport"));
					
				Else
					
					Execute(PGCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(52, ErrorDescription(), OCR, PGCR,
					Source, "AfterExportingsGroupsProperties",, False);
				
				Break;
			EndTry; 
			
			If Cancel Then	//	Denial of the subordinate object export.
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If PGCR.XMLNodeRequiredOnExport Then
			AddSubordinate(ObjectCollectionNode, CollectionObjectNode);
		EndIf;
		
		// Fill in file with node objects.
		If ExportGroupToFile Then
			
			CollectionObjectNode.WriteEndElement();
			InformationToWriteToFile = CollectionObjectNode.Close();
			TempRecordFile.WriteLine(InformationToWriteToFile);
			
		Else
			
			If Not PGCR.XMLNodeRequiredOnExport Then
				
				ObjectCollectionNode.WriteEndElement();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	
    // Handler AfterDataExportProcessor

	If PGCR.HasAfterProcessExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PGCR, "AfterProcessExport"));
				
			Else
				
				Execute(PGCR.AfterProcessExport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorPCRHandlers(49, ErrorDescription(), OCR, PGCR,
				Source, "AfterProcessPropertyGroupExport",, False);
			
		EndTry;
		
		If Cancel Then	//	Denial of writing the subordinate objects.
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ExportGroupToFile Then
		TempRecordFile.WriteLine("</" + MasterNodeName + ">"); // close node
		TempRecordFile.Close(); 	// close file clearly
	Else
		WriteDataIntoHeadNode(PropertyCollectionNode, PropertyNodeStructure, ObjectCollectionNode);
	EndIf;

EndProcedure

Procedure GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source)
	
	If Value <> Undefined Then
		Return;
	EndIf;
	
	If PCR.GetFromIncomingData Then
			
			ObjectForReceivingData = IncomingData;
			
			If Not IsBlankString(PCR.Receiver) Then
			
				PropertyName = PCR.Receiver;
				
			Else
				
				PropertyName = PCR.ParameterForTransferName;
				
			EndIf;
			
			ErrorCode = ?(CollectionObject <> Undefined, 67, 68);
	
	ElsIf CollectionObject <> Undefined Then
		
		ObjectForReceivingData = CollectionObject;
		
		If Not IsBlankString(PCR.Source) Then
			
			PropertyName = PCR.Source;
			ErrorCode = 16;
						
		Else
			
			PropertyName = PCR.Receiver;
			ErrorCode = 17;
			
		EndIf;
		
	Else
		
		ObjectForReceivingData = Source;
		
		If Not IsBlankString(PCR.Source) Then
		
			PropertyName = PCR.Source;
			ErrorCode = 13;
		
		Else
			
			PropertyName = PCR.Receiver;
			ErrorCode = 14;
			
		EndIf;
		
	EndIf;
	
	Try
		
		Value = ObjectForReceivingData[PropertyName];
		
	Except
		
		If ErrorCode <> 14 Then
			WriteInformationAboutErrorPCRHandlers(ErrorCode, ErrorDescription(), OCR, PCR, Source, "");
		EndIf;
		
	EndTry;
	
EndProcedure

Procedure DumpItemPropertyType(Propirtiesnode, PropertyType)
	
	SetAttribute(Propirtiesnode, "Type", PropertyType);	
	
EndProcedure

Procedure ExportExtraDimension(Source,
							Receiver,
							IncomingData,
							OutgoingData,
							OCR,
							PCR,
							PropertyCollectionNode ,
							CollectionObject,
							Val ExportRefOnly)
	//
	// Variable-caps to support mechanism of the
	// event handlers code debugging (support of the handler procedure- wrapper interface).
	Var ReceiverType, Empty, Expression, Donotreplace, Propirtiesnode, OCRProperties;
	
	// Initialize value
	Value = Undefined;
	OCRName = "";
	OCRNameextdimensiontype = "";
	
	// Handler BeforeExport
	If PCR.HasBeforeExportHandler Then
		
		Cancel = False;
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(PCR, "BeforeExport"));
				
			Else
				
				Execute(PCR.BeforeExport);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
				"BeforeExportProperty", Value);
				
		EndTry;
			
		If Cancel Then // Denial of the export
			
			Return;
			
		EndIf;
		
	EndIf;
	
	GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
	
	If PCR.CastToLength <> 0 Then
		
		RunValueCastToLength(Value, PCR);
		
	EndIf;
		
	For Each KeyAndValue IN Value Do
		
		ExtDimensionType = KeyAndValue.Key;
		ExtDimension = KeyAndValue.Value;
		OCRName = "";
		
		// Handler OnExport
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
					"OnExportProperty", Value);
				
			EndTry;
				
			If Cancel Then // Denial of the extra dimension export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		If ExtDimension = Undefined
			OR FindRule(ExtDimension, OCRName) = Undefined Then
			
			Continue;
			
		EndIf;
			
		Nodeextdimension = CreateNode(PCR.Receiver);
		
		// Key
		Propirtiesnode = CreateNode("Property");
		
		If IsBlankString(OCRNameextdimensiontype) Then
			
			OCRKey = FindRule(ExtDimensionType, OCRNameextdimensiontype);
			
		Else
			
			OCRKey = FindRule(, OCRNameextdimensiontype);
			
		EndIf;
		
		SetAttribute(Propirtiesnode, "Name", "Key");
		DumpItemPropertyType(Propirtiesnode, OCRKey.Receiver);
			
		Referencenode = DumpByRule(ExtDimensionType,, OutgoingData,, OCRNameextdimensiontype,, ExportRefOnly, OCRKey);
			
		If Referencenode <> Undefined Then
			
			IsRuleWithGlobalExport = False;
			RefNodeType = TypeOf(Referencenode);
			AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport);
			
		EndIf;
		
		AddSubordinate(Nodeextdimension, Propirtiesnode);
		
		// Value
		Propirtiesnode = CreateNode("Property");
		
		OCRValue = FindRule(ExtDimension, OCRName);
		
		ReceiverType = OCRValue.Receiver;
		
		IsNULL = False;
		Empty = deBlank(ExtDimension, IsNULL);
		
		If Empty Then
			
			If IsNULL 
				Or ExtDimension = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(ReceiverType) Then
				
				ReceiverType = DefineDataTypeForReceiver(ExtDimension);
				
			EndIf;
			
			SetAttribute(Propirtiesnode, "Name", "Value");
			
			If Not IsBlankString(ReceiverType) Then
				SetAttribute(Propirtiesnode, "Type", ReceiverType);
			EndIf;
			
			// If the type is a multiple one, then it may be an empty reference and you should export it specifying its type.
			deWriteItem(Propirtiesnode, "Empty");
			
			AddSubordinate(Nodeextdimension, Propirtiesnode);
			
		Else
			
			IsRuleWithGlobalExport = False;
			Referencenode = DumpByRule(ExtDimension,, OutgoingData, , OCRName, , ExportRefOnly, OCRValue, IsRuleWithGlobalExport);
			
			SetAttribute(Propirtiesnode, "Name", "Value");
			DumpItemPropertyType(Propirtiesnode, ReceiverType);
			
			If Referencenode = Undefined Then
				
				Continue;
				
			EndIf;
			
			RefNodeType = TypeOf(Referencenode);
			
			AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport);
			
			AddSubordinate(Nodeextdimension, Propirtiesnode);
			
		EndIf;
		
		// Handler AfterExport
		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
					
			Except
					
				WriteInformationAboutErrorPCRHandlers(57, ErrorDescription(), OCR, PCR, Source,
					"AfterExportProperty", Value);
					
			EndTry;
			
			If Cancel Then // Denial of the export
				
				Continue;
				
			EndIf;
			
		EndIf;
		
		AddSubordinate(PropertyCollectionNode, Nodeextdimension);
		
	EndDo;
	
EndProcedure

Procedure AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport)
	
	If RefNodeType = deStringType Then
				
		If Find(Referencenode, "<Ref") > 0 Then
					
			Propirtiesnode.WriteRaw(Referencenode);
					
		Else
			
			deWriteItem(Propirtiesnode, "Value", Referencenode);
					
		EndIf;
				
	ElsIf RefNodeType = deNumberType Then
		
		If IsRuleWithGlobalExport Then
		
			deWriteItem(Propirtiesnode, "GSn", Referencenode);
			
		Else     		
			
			deWriteItem(Propirtiesnode, "NPP", Referencenode);
			
		EndIf;
				
	Else
				
		AddSubordinate(Propirtiesnode, Referencenode);
				
	EndIf;	
	
EndProcedure

Procedure AddPropertyValueToNode(Value, ValueType, ReceiverType, Propirtiesnode, PropertySet)
	
	PropertySet = True;
		
	If ValueType = deStringType Then
				
		If ReceiverType = "String"  Then
		ElsIf ReceiverType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf ReceiverType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf ReceiverType = "Date"  Then
					
			Value = Date(Value);
					
		ElsIf ReceiverType = "ValueStorage"  Then
					
			Value = New ValueStorage(Value);
					
		ElsIf ReceiverType = "UUID" Then
					
			Value = New UUID(Value);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			SetAttribute(Propirtiesnode, "Type", "String");
					
		EndIf;
				
		deWriteItem(Propirtiesnode, "Value", Value);
				
	ElsIf ValueType = deNumberType Then
				
		If ReceiverType = "Number"  Then
		ElsIf ReceiverType = "Boolean"  Then
					
			Value = Boolean(Value);
					
		ElsIf ReceiverType = "String"  Then
		ElsIf IsBlankString(ReceiverType) Then
					
			SetAttribute(Propirtiesnode, "Type", "Number");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteItem(Propirtiesnode, "Value", Value);
				
	ElsIf ValueType = deDateType Then
				
		If ReceiverType = "Date"  Then
		ElsIf ReceiverType = "String"  Then
					
			Value = Left(String(Value), 10);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			SetAttribute(Propirtiesnode, "Type", "Date");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteItem(Propirtiesnode, "Value", Value);
				
	ElsIf ValueType = deBooleanType Then
				
		If ReceiverType = "Boolean"  Then
		ElsIf ReceiverType = "Number"  Then
					
			Value = Number(Value);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			SetAttribute(Propirtiesnode, "Type", "Boolean");
					
		Else
					
			Return;
					
		EndIf;
				
		deWriteItem(Propirtiesnode, "Value", Value);
				
	ElsIf ValueType = deValueStorageType Then
				
		If IsBlankString(ReceiverType) Then
					
			SetAttribute(Propirtiesnode, "Type", "ValueStorage");
					
		ElsIf ReceiverType <> "ValueStorage"  Then
					
			Return;
					
		EndIf;
				
		deWriteItem(Propirtiesnode, "Value", Value);
				
	ElsIf ValueType = deUUIDType Then
		
		If ReceiverType = "UUID" Then
		ElsIf ReceiverType = "String"  Then
					
			Value = String(Value);
					
		ElsIf IsBlankString(ReceiverType) Then
					
			SetAttribute(Propirtiesnode, "Type", "UUID");
					
		Else
					
			Return;
					
		EndIf;
		
		deWriteItem(Propirtiesnode, "Value", Value);
		
	ElsIf ValueType = deAccumulationRecordTypeType Then
				
		deWriteItem(Propirtiesnode, "Value", String(Value));		
		
	Else	
		
		PropertySet = False;
		
	EndIf;	
	
EndProcedure


Function DumpReferenceObjectData(Value, OutgoingData, OCRName, OCRProperties, ReceiverType, Propirtiesnode, Val ExportRefOnly)
	
	IsRuleWithGlobalExport = False;
	Referencenode    = DumpByRule(Value, , OutgoingData, , OCRName, , ExportRefOnly, OCRProperties, IsRuleWithGlobalExport);
	RefNodeType = TypeOf(Referencenode);

	If IsBlankString(ReceiverType) Then
				
		ReceiverType  = OCRProperties.Receiver;
		SetAttribute(Propirtiesnode, "Type", ReceiverType);
				
	EndIf;
			
	If Referencenode = Undefined Then
				
		Return Undefined;
				
	EndIf;
				
	AddPropertiesForDump(Referencenode, RefNodeType, Propirtiesnode, IsRuleWithGlobalExport);	
	
	Return Referencenode;
	
EndFunction

Function DefineDataTypeForReceiver(Value)
	
	ReceiverType = deValueTypeAsString(Value);
	
	// Whether there is OCR with the ReceiverType
	// receiver type if there is no rule - then "" if there is , , then keep what you found.
	TableRow = ConversionRulesTable.Find(ReceiverType, "Receiver");
	
	If TableRow = Undefined Then
		ReceiverType = "";
	EndIf;
	
	Return ReceiverType;
	
EndFunction

Procedure RunValueCastToLength(Value, PCR)
	
	Value = CastNumberToLength(String(Value), PCR.CastToLength);
		
EndProcedure

// Generates receiver object property nodes according to the specified properties conversion rules collection.
//
// Parameters:
//  Source		     - custom data source.
//  Receiver		     - receiver object xml-node.
//  IncomingData	     - custom helper data passed
//                         to rule for conversion execution.
//  OutgoingData      - custom helper data passed
//                         to property objects conversion rules.
//  OCR				     - ref to object conversion rule (parent of the properties conversion rules collection).
//  PCRCollection         - properties conversion rules collection.
//  PropertyCollectionNode - properties collection xml-node.
//  CollectionObject      - if it is specified, then collection object properties are exported, otherwise, Source properties are exported.
//  PredefinedItemName - if it is specified, then predefined item name is written.
//  PGCR                 - ref to the properties group conversion rule (folder-parent of PCR collection). 
//                         For example, document tabular section.
// 
Procedure DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PCRCollection, PropertyCollectionNode = Undefined, 
	CollectionObject = Undefined, PredefinedItemName = Undefined, Val ExportRefOnly = False, 
	TempFileList = Undefined)
	
	Var KeyAndValue, ExtDimensionType, ExtDimension, OCRNameextdimensiontype, Nodeextdimension; // Dummies for
	                                                                             // correct handlers start.
	
	If PropertyCollectionNode = Undefined Then
		
		PropertyCollectionNode = Receiver;
		
	EndIf;
	
	// Export a name of the predefined one if it is specified.
	If PredefinedItemName <> Undefined Then
		
		PropertyCollectionNode.WriteStartElement("Property");
		SetAttribute(PropertyCollectionNode, "Name", "{PredefinedItemName}");
		If Not ExecuteDataExchangeInOptimizedFormat Then
			SetAttribute(PropertyCollectionNode, "Type", "String");
		EndIf;
		deWriteItem(PropertyCollectionNode, "Value", PredefinedItemName);
		PropertyCollectionNode.WriteEndElement();		
		
	EndIf;
		
	For Each PCR IN PCRCollection Do
		
		If PCR.SimplifiedPropertyExport Then
						
			 //	Create property node
			 
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", PCR.Receiver);
			
			If Not ExecuteDataExchangeInOptimizedFormat
				AND Not IsBlankString(PCR.ReceiverType) Then
			
				SetAttribute(PropertyCollectionNode, "Type", PCR.ReceiverType);
				
			EndIf;
			
			If PCR.Donotreplace Then
				
				SetAttribute(PropertyCollectionNode, "Donotreplace",	"true");
				
			EndIf;
			
			If PCR.SearchByEqualDate  Then
				
				SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
				
			EndIf;
			
			Value = Undefined;
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				RunValueCastToLength(Value, PCR);
								
			EndIf;
			
			IsNULL = False;
			Empty = deBlank(Value, IsNULL);
						
			If Empty Then
				
				// You should note that this value is empty.
				If Not ExecuteDataExchangeInOptimizedFormat Then
					deWriteItem(PropertyCollectionNode, "Empty");
				EndIf;
				
				PropertyCollectionNode.WriteEndElement();
				Continue;
				
			EndIf;
			
			deWriteItem(PropertyCollectionNode,	"Value", Value);
			
			PropertyCollectionNode.WriteEndElement();
			Continue;	
			
		ElsIf PCR.TargetKind = "AccountExtDimensionTypes" Then
			
			ExportExtraDimension(Source, Receiver, IncomingData, OutgoingData, OCR,
				PCR, PropertyCollectionNode, CollectionObject, ExportRefOnly);
			
			Continue;
			
		ElsIf PCR.Name = "{UUID}" 
			AND PCR.Source = "{UUID}" 
			AND PCR.Receiver = "{UUID}" Then
			
			Try
				
				UUID = Source.UUID();
				
			Except
				
				UUID = Source.Ref.UUID();
				
			EndTry;
			
			PropertyCollectionNode.WriteStartElement("Property");
			SetAttribute(PropertyCollectionNode, "Name", "{UUID}");
			
			If Not ExecuteDataExchangeInOptimizedFormat Then 
				SetAttribute(PropertyCollectionNode, "Type", "String");
			EndIf;
			
			deWriteItem(PropertyCollectionNode, "Value", UUID);
			PropertyCollectionNode.WriteEndElement();
			Continue;
			
		ElsIf PCR.IsFolder Then
			
			DumpGroupOfProperties(Source, Receiver, IncomingData, OutgoingData, OCR, PCR, PropertyCollectionNode, ExportRefOnly, TempFileList);
			Continue;
			
		EndIf;

		
		//	Initialize value that will be converted.
		Value 	 = Undefined;
		OCRName		 = PCR.ConversionRule;
		Donotreplace   = PCR.Donotreplace;
		
		Empty		 = False;
		Expression	 = Undefined;
		ReceiverType = PCR.ReceiverType;

		IsNULL      = False;

		
		// Handler BeforeExport
		If PCR.HasBeforeExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "BeforeExport"));
					
				Else
					
					Execute(PCR.BeforeExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(55, ErrorDescription(), OCR, PCR, Source, 
						"BeforeExportProperty", Value);
														
			EndTry;
				                             
			If Cancel Then	//	Denial of the property export
				
				Continue;
				
			EndIf;
			
		EndIf;

        		
        //	Create property node
		If IsBlankString(PCR.ParameterForTransferName) Then
			
			Propirtiesnode = CreateNode("Property");
			SetAttribute(Propirtiesnode, "Name", PCR.Receiver);
			
		Else
			
			Propirtiesnode = CreateNode("ParameterValue");
			SetAttribute(Propirtiesnode, "Name", PCR.ParameterForTransferName);
			
		EndIf;
		
		If Donotreplace Then
			
			SetAttribute(Propirtiesnode, "Donotreplace",	"true");
			
		EndIf;
		
		If PCR.SearchByEqualDate  Then
			
			SetAttribute(PropertyCollectionNode, "SearchByEqualDate", "true");
			
		EndIf;

        		
		//	Conversion rule may have already been determined.
		If Not IsBlankString(OCRName) Then
			
			OCRProperties = Rules[OCRName];
			
		Else
			
			OCRProperties = Undefined;
			
		EndIf;


		//	Attempt to determine receiver property type.
		If IsBlankString(ReceiverType)	AND OCRProperties <> Undefined Then
			
			ReceiverType = OCRProperties.Receiver;
			SetAttribute(Propirtiesnode, "Type", ReceiverType);
			
		ElsIf Not ExecuteDataExchangeInOptimizedFormat 
			AND Not IsBlankString(ReceiverType) Then
			
			SetAttribute(Propirtiesnode, "Type", ReceiverType);
						
		EndIf;
		
		If Not IsBlankString(OCRName)
			AND OCRProperties <> Undefined
			AND OCRProperties.HasSearchFieldSequenceHandler = True Then
			
			SetAttribute(Propirtiesnode, "OCRName", OCRName);
			
		EndIf;
		
        //	Determine converted value.
		If Expression <> Undefined Then
			
			deWriteItem(Propirtiesnode, "Expression", Expression);
			AddSubordinate(PropertyCollectionNode, Propirtiesnode);
			Continue;
			
		ElsIf Empty Then
			
			If IsBlankString(ReceiverType) Then
				
				Continue;
				
			EndIf;
			
			If Not ExecuteDataExchangeInOptimizedFormat Then 
				deWriteItem(Propirtiesnode, "Empty");
			EndIf;
			
			AddSubordinate(PropertyCollectionNode, Propirtiesnode);
			Continue;
			
		Else
			
			GetPropertyValue(Value, CollectionObject, OCR, PCR, IncomingData, Source);
			
			If PCR.CastToLength <> 0 Then
				
				RunValueCastToLength(Value, PCR);
								
			EndIf;
						
		EndIf;


		OldValueBeforeOnExportHandler = Value;
		Empty = deBlank(Value, IsNULL);

		
		// Handler OnExport
		If PCR.HasOnExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "OnExport"));
					
				Else
					
					Execute(PCR.OnExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(56, ErrorDescription(), OCR, PCR, Source, 
						"OnExportProperty", Value);
														
			EndTry;
				
			If Cancel Then	//	Denial of the property export
				
				Continue;
				
			EndIf;
			
		EndIf;


		// Once again initialize the Empty variable, Value may have been changed in the handler "On export".
		If OldValueBeforeOnExportHandler <> Value Then
			
			Empty = deBlank(Value, IsNULL);
			
		EndIf;

		If Empty Then
			
			If IsNULL 
				Or Value = Undefined Then
				
				Continue;
				
			EndIf;
			
			If IsBlankString(ReceiverType) Then
				
				ReceiverType = DefineDataTypeForReceiver(Value);
				
				If Not IsBlankString(ReceiverType) Then				
				
					SetAttribute(Propirtiesnode, "Type", ReceiverType);
				
				EndIf;
				
			EndIf;			
				
			// If the type is a multiple one, then it may be an empty reference and you should export it specifying its type.
			If Not ExecuteDataExchangeInOptimizedFormat Then
				deWriteItem(Propirtiesnode, "Empty");
			EndIf;
			
			AddSubordinate(PropertyCollectionNode, Propirtiesnode);
			Continue;
			
		EndIf;

      		
		Referencenode = Undefined;
		
		If (OCRProperties <> Undefined) 
			Or (NOT IsBlankString(OCRName)) Then
			
			Referencenode = DumpReferenceObjectData(Value, OutgoingData, OCRName, OCRProperties, ReceiverType, Propirtiesnode, ExportRefOnly);
			
			If Referencenode = Undefined Then
				Continue;				
			EndIf;				
										
		Else
			
			PropertySet = False;
			ValueType = TypeOf(Value);
			AddPropertyValueToNode(Value, ValueType, ReceiverType, Propirtiesnode, PropertySet);
						
			If Not PropertySet Then
				
				ValueManager = Managers[ValueType];
				
				If ValueManager = Undefined Then
					Continue;
				EndIf;
				
				OCRProperties = ValueManager.OCR;
				
				If OCRProperties = Undefined Then
					Continue;
				EndIf;
				
				OCRName = OCRProperties.Name;
				
				Referencenode = DumpReferenceObjectData(Value, OutgoingData, OCRName, OCRProperties, ReceiverType, Propirtiesnode, ExportRefOnly);
			
				If Referencenode = Undefined Then
					Continue;				
				EndIf;				
												
			EndIf;
			
		EndIf;


		
		// Handler AfterExport

		If PCR.HasAfterExportHandler Then
			
			Cancel = False;
			
			Try
				
				If HandlersDebugModeFlag Then
					
					Execute(GetHandlerCallString(PCR, "AfterExport"));
					
				Else
					
					Execute(PCR.AfterExport);
					
				EndIf;
				
			Except
				
				WriteInformationAboutErrorPCRHandlers(57, ErrorDescription(), OCR, PCR, Source, 
						"AfterExportProperty", Value);					
				
			EndTry;
				
			If Cancel Then	//	Denial of the property export
				
				Continue;
				
			EndIf;
			
		EndIf;

		
		AddSubordinate(PropertyCollectionNode, Propirtiesnode);
		
	EndDo;		//	by PCR

EndProcedure

// Exports object according to the specified conversion rule.
//
// Parameters:
//  Source				 - custom data source.
//  Receiver				 - receiver object xml-node.
//  IncomingData			 - custom helper data passed
//                             to rule for conversion execution.
//  OutgoingData			 - custom helper data passed
//                             to the properties conversion rules.
//  OCRName					 - conversion rule name according to which export is executed.
//  Referencenode				 - xml-node of receiver object reference.
//  GetRefNodeOnly - if true, then object is not exported, only
//                             xml-node is generated.
//  OCR						 - ref to the conversion rule.
//
// Returns:
//  ref xml-node or receiver value.
//
Function DumpByRule(Source					= Undefined,
						   Receiver					= Undefined,
						   IncomingData			= Undefined,
						   OutgoingData			= Undefined,
						   OCRName					= "",
						   Referencenode				= Undefined,
						   GetRefNodeOnly	= False,
						   OCR						= Undefined,
						   IsRuleWithGlobalObjectExport = False,
						   SelectionForDataExport = Undefined) Export
	
	// Search OCR
	If OCR = Undefined Then
		
		OCR = FindRule(Source, OCRName);
		
	ElsIf (NOT IsBlankString(OCRName))
		AND OCR.Name <> OCRName Then
		
		OCR = FindRule(Source, OCRName);
				
	EndIf;	
	
	If OCR = Undefined Then
		
		LR = GetProtocolRecordStructure(45);
		
		LR.Object = Source;
		LR.ObjectType = TypeOf(Source);
		
		WriteInExecutionProtocol(45, LR, True); // OCR is not found
		Return Undefined;
		
	EndIf;

	If CommentObjectProcessingFlag Then
		
		DescriptionOfType = New TypeDescription("String");
		SourceToString = DescriptionOfType.AdjustValue(Source);
		SourceToString = ?(SourceToString = "", " ", SourceToString);
		
		ObjectPresentation = SourceToString + "  (" + TypeOf(Source) + ")";
		
		OCRNameString = " OCR: " + TrimAll(OCRName) + "  (" + TrimAll(OCR.Description) + ")";
		
		StringForUser = ?(GetRefNodeOnly, NStr("en='Convert reference to object: %1';ru='Конвертация ссылки на объект: %1'"), NStr("en='Object conversion: %1';ru='Конвертация объекта: %1'"));
		StringForUser = PlaceParametersIntoString(StringForUser, ObjectPresentation);
		
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule + 1;
		
		WriteInExecutionProtocol(StringForUser + OCRNameString, , False, CurrentNestingLevelExportByRule + 1, 7);
		
	EndIf;
	
	IsRuleWithGlobalObjectExport = ExecuteDataExchangeInOptimizedFormat AND OCR.UseQuickSearchOnImport;

    RememberExported       = OCR.RememberExported;
	ExportedObjects          = OCR.Exported;
	ExportedObjectsOnlyRefs = OCR.OnlyRefsExported;
	AllObjectsAreExported         = OCR.AllObjectsAreExported;
	DoNotReplaceObjectOnImport = OCR.Donotreplace;
	DoNotCreateIfNotFound     = OCR.DoNotCreateIfNotFound;
	OnExchangeObjectByRefSetGIUDOnly     = OCR.OnExchangeObjectByRefSetGIUDOnly;
	
	AutonumerationPrefix		= "";
	WriteMode     			= "";
	PostingMode 			= "";
	TempFileList = Undefined;

   	TypeName          = "";
	PropertyStructure = Managers[OCR.Source];
	If PropertyStructure = Undefined Then
		PropertyStructure = Managers[TypeOf(Source)];
	EndIf;
	
	If PropertyStructure <> Undefined Then
		TypeName = PropertyStructure.TypeName;
	EndIf;

	// ExportedDataKey
	
	If (Source <> Undefined) AND RememberExported Then
		If TypeName = "InformationRegister" OR TypeName = "Constants" OR IsBlankString(TypeName) Then
			RememberExported = False;
		Else
			ExportedDataKey = ValueToStringInternal(Source);
		EndIf;
	Else
		ExportedDataKey = OCRName;
		RememberExported = False;
	EndIf;
	
	
	// Variable for predefined item name storage.
	PredefinedItemName = Undefined;

	// BeforeObjectConversion global handler.
    Cancel = False;	
	If HasBeforeConvertObjectGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeObjectConversion"));

			Else
				
				Execute(Conversion.BeforeObjectConversion);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(64, ErrorDescription(), OCR, Source, NStr("en='BeforeObjectConversion (global)';ru='ПередКонвертациейОбъекта (глобальный)'"));
		EndTry;
		
		If Cancel Then	//	Denial of the further rule data processor.
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Receiver;
		EndIf;
		
	EndIf;
	
	// Handler BeforeExport
	If OCR.HasBeforeExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "BeforeExport"));
				
			Else
				
				Execute(OCR.BeforeExport);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(41, ErrorDescription(), OCR, Source, "BeforeObjectExport");
		EndTry;
		
		If Cancel Then	//	Denial of the further rule data processor.
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Receiver;
		EndIf;
		
	EndIf;
	
	// This data may have already been exported.
	If Not AllObjectsAreExported Then
		
		NPP = 0;
		
		If RememberExported Then
			
			Referencenode = ExportedObjects[ExportedDataKey];
			If Referencenode <> Undefined Then
				
				If GetRefNodeOnly Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return Referencenode;
				EndIf;
				
				ExportedRefNumber = ExportedObjectsOnlyRefs[ExportedDataKey];
				If ExportedRefNumber = Undefined Then
					CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
					Return Referencenode;
				Else
					
					ExportStackRow = mDataExportCallStack.Find(ExportedDataKey, "Ref");
				
					If ExportStackRow <> Undefined Then
						CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
						Return Referencenode;
					EndIf;
					
					ExportStackRow = mDataExportCallStack.Add();
					ExportStackRow.Ref = ExportedDataKey;
					
					NPP = ExportedRefNumber;
				EndIf;
			EndIf;
			
		EndIf;
		
		If NPP = 0 Then
			
			mSnCounter = mSnCounter + 1;
			NPP         = mSnCounter;
			
		EndIf;
		
		// It will allow to avoid circular refs.
		If RememberExported Then
			
			ExportedObjects[ExportedDataKey] = NPP;
			If GetRefNodeOnly Then
				ExportedObjectsOnlyRefs[ExportedDataKey] = NPP;
			Else
				
				ExportStackRow = mDataExportCallStack.Add();
				ExportStackRow.Ref = ExportedDataKey;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ValueMap = OCR.Values;
	ValueMapItemCount = ValueMap.Count();
	
	// Data  processor of predefined item matches.
	If TargetPlatform = "V8" Then
		
		// If predefined item name is not determined yet, try to determine it.
		If PredefinedItemName = Undefined Then
			
			If PropertyStructure <> Undefined
				AND ValueMapItemCount > 0
				AND PropertyStructure.SearchByPredefinedPossible Then
			
				Try
					PredefinedNameSource = PredefinedName(Source);
				Except
					PredefinedNameSource = "";
				EndTry;
				
			Else
				
				PredefinedNameSource = "";
				
			EndIf;
			
			If Not IsBlankString(PredefinedNameSource)
				AND ValueMapItemCount > 0 Then
				
				PredefinedItemName = ValueMap[Source];
				
			Else
				PredefinedItemName = Undefined;
			EndIf;
			
		EndIf;
		
		If PredefinedItemName <> Undefined Then
			ValueMapItemCount = 0;
		EndIf;
		
	Else
		PredefinedItemName = Undefined;
	EndIf;
	
	DontExportByValueMap = (ValueMapItemCount = 0);
	
	If Not DontExportByValueMap Then
		
		// If there is no object in the values match - , export it regularly.
		Referencenode = ValueMap[Source];
		If Referencenode = Undefined
			AND OCR.SearchProperties.Count() > 0 Then
			
			// This may be conversion from enumeration to enumeration and you have not found by.
			// VCR required property - then just export empty reference.
			If PropertyStructure.TypeName = "Enum"
				AND Find(OCR.Receiver, "EnumRef.") > 0 Then
				
				Referencenode = "";
				
			Else
						
				DontExportByValueMap = True;	
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	MustRememberObject = RememberExported AND (NOT AllObjectsAreExported);

	If DontExportByValueMap Then
		
		If OCR.SearchProperties.Count() > 0 
			OR PredefinedItemName <> Undefined Then
			
			//	Generate ref node
			Referencenode = CreateNode("Ref");
			
			If MustRememberObject Then
				
				If IsRuleWithGlobalObjectExport Then
					SetAttribute(Referencenode, "GSn", NPP);
				Else
					SetAttribute(Referencenode, "NPP", NPP);
				EndIf;
				
			EndIf;
			
			ExportRefOnly = OCR.DontExportPropertyObjectsByRefs OR GetRefNodeOnly;
			
			If DoNotCreateIfNotFound Then
				SetAttribute(Referencenode, "DoNotCreateIfNotFound", DoNotCreateIfNotFound);
			EndIf;
			
			If OnExchangeObjectByRefSetGIUDOnly Then
				SetAttribute(Referencenode, "OnExchangeObjectByRefSetGIUDOnly", OnExchangeObjectByRefSetGIUDOnly);
			EndIf;
			
			DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, OCR.SearchProperties, 
				Referencenode, SelectionForDataExport, PredefinedItemName, OCR.DontExportPropertyObjectsByRefs OR GetRefNodeOnly);
			
			Referencenode.WriteEndElement();
			Referencenode = Referencenode.Close();
			
			If MustRememberObject Then
				
				ExportedObjects[ExportedDataKey] = Referencenode;
				
			EndIf;
			
		Else
			Referencenode = NPP;
		EndIf;
		
	Else
		
		// Search values by VCR in the match.
		If Referencenode = Undefined Then
			// You did not find by Values match - , try to find by search properties.
			RecordStructure = New Structure("Source,SourceType", Source, TypeOf(Source));
			WriteInExecutionProtocol(71, RecordStructure);
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Undefined;
		EndIf;
		
		If RememberExported Then
			ExportedObjects[ExportedDataKey] = Referencenode;
		EndIf;
		
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return Referencenode;
		
	EndIf;
	
	If GetRefNodeOnly Or AllObjectsAreExported Then
	
		If ExportStackRow <> Undefined Then
			mDataExportCallStack.Delete(ExportStackRow);
		EndIf;
		CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
		Return Referencenode;
		
	EndIf;

	If Receiver = Undefined Then
		
		Receiver = CreateNode("Object");
		
		If IsRuleWithGlobalObjectExport Then
			SetAttribute(Receiver, "GSn", NPP);
		Else
			SetAttribute(Receiver, "NPP", NPP);
		EndIf;
		
		SetAttribute(Receiver, "Type", 			OCR.Receiver);
		SetAttribute(Receiver, "Rulename",	OCR.Name);
		
		If DoNotReplaceObjectOnImport Then
			SetAttribute(Receiver, "Donotreplace",	"true");
		EndIf;
		
		If Not IsBlankString(AutonumerationPrefix) Then
			SetAttribute(Receiver, "AutonumerationPrefix",	AutonumerationPrefix);
		EndIf;
		
		If Not IsBlankString(WriteMode) Then
			SetAttribute(Receiver, "WriteMode",	WriteMode);
			If Not IsBlankString(PostingMode) Then
				SetAttribute(Receiver, "PostingMode",	PostingMode);
			EndIf;
		EndIf;
		
		If TypeOf(Referencenode) <> deNumberType Then
			AddSubordinate(Receiver, Referencenode);
		EndIf; 
		
	EndIf;

	// Handler OnExport
	StandardProcessing = True;
	Cancel = False;
	
	If OCR.HasOnExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "OnExport"));
				
			Else
				
				Execute(OCR.OnExport);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(42, ErrorDescription(), OCR, Source, "OnExportObject");
		EndTry;
		
		If Cancel Then	//	Denial of object writing to file.
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Referencenode;
		EndIf;
		
	EndIf;

	// Export property
	If StandardProcessing Then
		
		DumpProperties(Source, Receiver, IncomingData, OutgoingData, OCR, OCR.Properties, , SelectionForDataExport, ,
			OCR.DontExportPropertyObjectsByRefs OR GetRefNodeOnly, TempFileList);
			
	EndIf;
	
	// Handler AfterExport
	If OCR.HasAfterExportHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExport"));
				
			Else
				
				Execute(OCR.AfterExport);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(43, ErrorDescription(), OCR, Source, "AfterObjectExport");
		EndTry;
		
		If Cancel Then	//	Denial of object writing to file.
			
			If ExportStackRow <> Undefined Then
				mDataExportCallStack.Delete(ExportStackRow);
			EndIf;
			CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
			Return Referencenode;
			
		EndIf;
		
	EndIf;
	
	If TempFileList = Undefined Then
	
		//	Write object to file
		Receiver.WriteEndElement();
		WriteToFile(Receiver);
		
	Else
		
		WriteToFile(Receiver);
		
		TempFile = New TextReader;
		For Each TempFileName IN TempFileList Do
			
			TempFile.Open(TempFileName, TextEncoding.UTF8);
			
			TempFileLine = TempFile.ReadLine();
			While TempFileLine <> Undefined Do
				WriteToFile(TempFileLine);	
				TempFileLine = TempFile.ReadLine();
			EndDo;
			
			TempFile.Close();
			
			DeleteFiles(TempFileName); 
		EndDo;
		
		WriteToFile("</Object>");
		
	EndIf;
	
	mExportedObjectCounter = 1 + mExportedObjectCounter;
	
	If MustRememberObject Then
				
		If IsRuleWithGlobalObjectExport Then
			ExportedObjects[ExportedDataKey] = NPP;
		EndIf;
		
	EndIf;
	
	If ExportStackRow <> Undefined Then
		mDataExportCallStack.Delete(ExportStackRow);
	EndIf;
	
	CurrentNestingLevelExportByRule = CurrentNestingLevelExportByRule - 1;
	
	// Handler AfterExportToFile
	If OCR.HasAfterExportToFileHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(OCR, "AfterExportToFile"));
				
			Else
				
				Execute(OCR.AfterExportToFile);
				
			EndIf;
			
		Except
			WriteInformationAboutOCRHandlerErrorDump(76, ErrorDescription(), OCR, Source, "HasAfterExportToFileHandler");
		EndTry;				
				
	EndIf;	
	
	Return Referencenode;

EndFunction	//	ExportByRule()

// Exports selection object according to the specified rule.
//
// Parameters:
//  Object         - selection exported object.
//  Rule        - ref to the data export rule.
//  Properties       - metadata object property of the exported object.
//  IncomingData - custom helper data.
// 
Procedure ExportSelectionObject(Object, Rule, Properties=Undefined, IncomingData=Undefined, SelectionForDataExport = Undefined)

	If CommentObjectProcessingFlag Then
		
		TypeDescription = New TypeDescription("String");
		RowObject  = TypeDescription.AdjustValue(Object);
		If Not IsBlankString(RowObject) Then
			ObjectPresentation   = RowObject + "  (" + TypeOf(Object) + ")";
		Else
			ObjectPresentation   = TypeOf(Object);
		EndIf;
		
		MessageString = PlaceParametersIntoString(NStr("en='Export object: %1';ru='Выгрузка объекта: %1'"), ObjectPresentation);
		WriteInExecutionProtocol(MessageString, , False, 1, 7);
		
	EndIf;
	
	OCRName			= Rule.ConversionRule;
	Cancel			= False;
	OutgoingData	= Undefined;
	
	// Global handler BeforeObjectExport.
	If HasBeforeObjectExportGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeObjectExport"));
				
			Else
				
				Execute(Conversion.BeforeObjectExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(65, ErrorDescription(), Rule.Name, NStr("en='BeforeExportSelectionObject (global)';ru='ПередВыгрузкойОбъектаВыборки (глобальный)'"), Object);
		EndTry;
			
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	// Handler BeforeExport
	If Not IsBlankString(Rule.BeforeExport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeExport"));
				
			Else
				
				Execute(Rule.BeforeExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(33, ErrorDescription(), Rule.Name, "BeforeExportSelectionObject", Object);
		EndTry;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	Referencenode = Undefined;
	
	DumpByRule(Object, , OutgoingData, , OCRName, Referencenode, , , , SelectionForDataExport);
	
	// Global handler AfterObjectExport.
	If HasAfterObjectExportGlobalHandler Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterObjectExport"));
				
			Else
				
				Execute(Conversion.AfterObjectExport);
			
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(69, ErrorDescription(), Rule.Name, NStr("en='AfterSelectionObjectExport (Global)';ru='ПослеВыгрузкиОбъектаВыборки (глобальный)'"), Object);
		EndTry;
		
	EndIf;
	
	// Handler AfterExport
	If Not IsBlankString(Rule.AfterExport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterExport"));
				
			Else
				
				Execute(Rule.AfterExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorDDRHandlers(34, ErrorDescription(), Rule.Name, "AfterSelectionObjectExport", Object);
		EndTry;
		
	EndIf;
	
EndProcedure

Function GetNameOfFirstAttributeOfMetadata(ObjectMetadata)
	
	If ObjectMetadata.Attributes.Count() = 0 Then
		Return "";
	EndIf;
	
	Return ObjectMetadata.Attributes[0].Name;
	
EndFunction

// Returns query language text fragment that is the restriction condition on dates interval.
//
Function GetStringOfRestrictionByDateForQuery(Properties, TypeName, TableGroupName = "", SelectionForDataClearing = False) Export
	
	ResultingDateRestriction = "";
	
	If Not (TypeName = "Document" OR TypeName = "InformationRegister") Then
		Return ResultingDateRestriction;
	EndIf;
	
	If TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodical;
		RestrictionByDateNotRequired = SelectionForDataClearing	OR Nonperiodical;
		
		If RestrictionByDateNotRequired Then
			Return ResultingDateRestriction;
		EndIf;
				
	EndIf;	
	
	If IsBlankString(TableGroupName) Then
		RestrictionFieldName = ?(TypeName = "Document", "Date", "Period");
	Else
		RestrictionFieldName = TableGroupName + "." + ?(TypeName = "Document", "Date", "Period");
	EndIf;
	
	If StartDate <> EmptyDateValue Then
		
		ResultingDateRestriction = "
		|	WHERE
		|		" + RestrictionFieldName + " >= &StartDate";
		
	EndIf;
		
	If EndDate <> EmptyDateValue Then
		
		If IsBlankString(ResultingDateRestriction) Then
			
			ResultingDateRestriction = "
			|	WHERE
			|		" + RestrictionFieldName + " <= &EndDate";
			
		Else
			
			ResultingDateRestriction = ResultingDateRestriction + "
			|	AND
			|		" + RestrictionFieldName + " <= &EndDate";
			
		EndIf;
		
	EndIf;
	
	Return ResultingDateRestriction;
	
EndFunction

// Generates query result to export data clearing.
//
Function GetQueryResultForDataDumpClear(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export 
	
	AllowedString = ?(ExportAllowedOnly, " ALLOWED ", "");
			
	FieldSelectionString = ?(SelectAllFields, " * ", "	ObjectForExport.Ref AS Ref ");
	
	If TypeName = "Catalog" 
		OR TypeName = "ChartOfCharacteristicTypes" 
		OR TypeName = "ChartOfAccounts" 
		OR TypeName = "ChartOfCalculationTypes" 
		OR TypeName = "AccountingRegister"
		OR TypeName = "ExchangePlan"
		OR TypeName = "Task"
		OR TypeName = "BusinessProcess" Then
		
		Query = New Query();
		
		If TypeName = "Catalog" Then
			ObjectsMetadata = Metadata.Catalogs[Properties.Name];
		ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		    ObjectsMetadata = Metadata.ChartsOfCharacteristicTypes[Properties.Name];			
		ElsIf TypeName = "ChartOfAccounts" Then
		    ObjectsMetadata = Metadata.ChartsOfAccounts[Properties.Name];
		ElsIf TypeName = "ChartOfCalculationTypes" Then
		    ObjectsMetadata = Metadata.ChartsOfCalculationTypes[Properties.Name];
		ElsIf TypeName = "AccountingRegister" Then
		    ObjectsMetadata = Metadata.AccountingRegisters[Properties.Name];
		ElsIf TypeName = "ExchangePlan" Then
		    ObjectsMetadata = Metadata.ExchangePlans[Properties.Name];
		ElsIf TypeName = "Task" Then
		    ObjectsMetadata = Metadata.Tasks[Properties.Name];
		ElsIf TypeName = "BusinessProcess" Then
		    ObjectsMetadata = Metadata.BusinessProcesses[Properties.Name];			
		EndIf;
		
		If TypeName = "AccountingRegister" Then
			
			FieldSelectionString = "*";
			SelectionTableName = Properties.Name + ".RecordsWithExtDimensions";
			
		Else
			
			SelectionTableName = Properties.Name;	
			
			If ExportAllowedOnly
				AND Not SelectAllFields Then
				
				FirstAttributeName = GetNameOfFirstAttributeOfMetadata(ObjectsMetadata);
				If Not IsBlankString(FirstAttributeName) Then
					FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		Query.Text = "SELECT " + AllowedString + "
		         |	" + FieldSelectionString + "
		         |IN
		         |	" + TypeName + "." + SelectionTableName + " AS ObjectForExport
				 |
				 |";
		
	ElsIf TypeName = "Document" Then
		
		If ExportAllowedOnly Then
			
			FirstAttributeName = GetNameOfFirstAttributeOfMetadata(Metadata.Documents[Properties.Name]);
			If Not IsBlankString(FirstAttributeName) Then
				FieldSelectionString = FieldSelectionString + ", ObjectForExport." + FirstAttributeName;
			EndIf;
			
		EndIf;
		
		ResultingDateRestriction = GetStringOfRestrictionByDateForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
		
		Query = New Query();
		
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		Query.Text = "SELECT " + AllowedString + "
		         |	" + FieldSelectionString + "
		         |IN
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
					 
											
	ElsIf TypeName = "InformationRegister" Then
		
		Nonperiodical = Not Properties.Periodical;
		SubordinatedToRecorder = Properties.SubordinatedToRecorder;		
		
		ResultingDateRestriction = GetStringOfRestrictionByDateForQuery(Properties, TypeName, "ObjectForExport", SelectionForDataClearing);
						
		Query = New Query();
		
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate", EndDate);
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(NOT SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		Query.Text = "SELECT " + AllowedString + "
		         |	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
				 | " + SelectionFieldSupplementionStringPeriodicity + "
				 |
		         |IN
		         |	" + TypeName + "." + Properties.Name + " AS ObjectForExport
				 |
				 |" + ResultingDateRestriction;
		
	Else
		
		Return Undefined;
					
	EndIf;	
	
	Return Query.Execute();
	
EndFunction

// Generates selection to export data clearing.
//
Function GetSelectionForDataDumpClear(Properties, TypeName, 
	SelectionForDataClearing = False, DeleteObjectsDirectly = False, SelectAllFields = True) Export
	
	QueryResult = GetQueryResultForDataDumpClear(Properties, TypeName, 
			SelectionForDataClearing, DeleteObjectsDirectly, SelectAllFields);
			
	If QueryResult = Undefined Then
		Return Undefined;
	EndIf;
			
	Selection = QueryResult.Select();
	
	Return Selection;
	
EndFunction

Function GetSelectionForDumpWithRestrictions(Rule, SelectionForSubstitutionToOCR = Undefined, Properties = Undefined)
	
	MetadataName           = Rule.ObjectForQueryName;
	
	AllowedString = ?(ExportAllowedOnly, " ALLOWED ", "");
	
	SelectionFields = "";
	
	IsRegisterExport = (Rule.ObjectForQueryName = Undefined);
	
	If IsRegisterExport Then
		
		Nonperiodical = Not Properties.Periodical;
		SubordinatedToRecorder = Properties.SubordinatedToRecorder;
		
		SelectionFieldSupplementionStringSubordinateToRegistrar = ?(NOT SubordinatedToRecorder, ", NULL AS Active,
		|	NULL AS Recorder,
		|	NULL AS LineNumber", "");
		
		SelectionFieldSupplementionStringPeriodicity = ?(Nonperiodical, ", NULL AS Period", "");
		
		ResultingDateRestriction = GetStringOfRestrictionByDateForQuery(Properties, Properties.TypeName, Rule.ObjectNameForRegisterQuery, False);
		
		ReportBuilder.Text = "SELECT " + AllowedString + "
		         |	*
				 |
				 | " + SelectionFieldSupplementionStringSubordinateToRegistrar + "
				 | " + SelectionFieldSupplementionStringPeriodicity + "
				 |
				 | IN " + Rule.ObjectNameForRegisterQuery + "
				 |
				 |" + ResultingDateRestriction;		
				 
		ReportBuilder.FillSettings();
				
	Else
		
		If Rule.SelectExportDataInSingleQuery Then
		
			// Select all object fields during the export.
			SelectionFields = "*";
			
		Else
			
			SelectionFields = "Ref AS Ref";
			
		EndIf;
		
		ResultingDateRestriction = GetStringOfRestrictionByDateForQuery(Properties, Properties.TypeName,, False);
		
		ReportBuilder.Text = "SELECT " + AllowedString + " " + SelectionFields + " IN " + MetadataName + "
		|
		|" + ResultingDateRestriction + "
		|
		|{WHERE Ref.* AS " + StrReplace(MetadataName, ".", "_") + "}";
		
	EndIf;
	
	ReportBuilder.Filter.Reset();
	If Rule.BuilderSettings <> Undefined Then
		ReportBuilder.SetSettings(Rule.BuilderSettings);
	EndIf;
	
	ReportBuilder.Parameters.Insert("StartDate", StartDate);
	ReportBuilder.Parameters.Insert("EndDate", EndDate);

	ReportBuilder.Execute();
	Selection = ReportBuilder.Result.Select();
	
	If Rule.SelectExportDataInSingleQuery Then
		SelectionForSubstitutionToOCR = Selection;
	EndIf;
		
	Return Selection;
		
EndFunction

Function GetSelectionForDumpByArbitraryAlgorithm(DataSelection)
	
	Selection = Undefined;
	
	SelectionType = TypeOf(DataSelection);
			
	If SelectionType = Type("QueryResultSelection") Then
				
		Selection = DataSelection;
		
	ElsIf SelectionType = Type("QueryResult") Then
				
		Selection = DataSelection.Select();
					
	ElsIf SelectionType = Type("Query") Then
				
		QueryResult = DataSelection.Execute();
		Selection          = QueryResult.Select();
									
	EndIf;
		
	Return Selection;	
	
EndFunction

Function GetConstantsSetStringForDump(ConstantDataTableForExport)
	
	ConstantsSetString = "";
	
	For Each TableRow IN ConstantDataTableForExport Do
		
		If Not IsBlankString(TableRow.Source) Then
		
			ConstantsSetString = ConstantsSetString + ", " + TableRow.Source;
			
		EndIf;
		
	EndDo;	
	
	If Not IsBlankString(ConstantsSetString) Then
		
		ConstantsSetString = Mid(ConstantsSetString, 3);
		
	EndIf;
	
	Return ConstantsSetString;
	
EndFunction

Procedure DumpConstantsSet(Rule, Properties, OutgoingData)
	
	If Properties.OCR <> Undefined Then
	
		ConstantsSetNameString = GetConstantsSetStringForDump(Properties.OCR.Properties);
		
	Else
		
		ConstantsSetNameString = "";
		
	EndIf;
			
	ConstantsSet = Constants.CreateSet(ConstantsSetNameString);
	ConstantsSet.Read();
	ExportSelectionObject(ConstantsSet, Rule, Properties, OutgoingData);	
	
EndProcedure

Function DefineNeedToSelectAllFields(Rule)
	
	AllFieldsRequiredForSelection = Not IsBlankString(Conversion.BeforeObjectExport)
		OR Not IsBlankString(Rule.BeforeExport)
		OR Not IsBlankString(Conversion.AfterObjectExport)
		OR Not IsBlankString(Rule.AfterExport);		
		
	Return AllFieldsRequiredForSelection;	
	
EndFunction

// Export data by the specified rule.
//
// Parameters:
//  Rule        - ref to the data export rule.
// 
Procedure DumpDataByRule(Rule)
	
	OCRName = Rule.ConversionRule;
	
	If Not IsBlankString(OCRName) Then
		
		OCR = Rules[OCRName];
		
	EndIf;
	
	If CommentObjectProcessingFlag Then
		
		MessageString = PlaceParametersIntoString(NStr("en='Data export rule: %1 (%2)';ru='Правило выгрузки данных: %1 (%2)'"), TrimAll(Rule.Name), TrimAll(Rule.Description));
		WriteInExecutionProtocol(MessageString, , False, , 4);
		
	EndIf;
	
	// Handler BeforeDataProcessor
	Cancel			= False;
	OutgoingData	= Undefined;
	DataSelection	= Undefined;
	
	If Not IsBlankString(Rule.BeforeProcess) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "BeforeProcess"));
				
			Else
				
				Execute(Rule.BeforeProcess);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorDDRHandlers(31, ErrorDescription(), Rule.Name, "BeforeProcessDataExport");
			
		EndTry;
		
		If Cancel Then
			
			Return;
			
		EndIf;
		
	EndIf;
	
	// Standard selection with filter.
	If Rule.DataSelectionVariant = "StandardSelection" AND Rule.UseFilter Then
		
		Properties	= Managers[Rule.SelectionObject];
		TypeName		= Properties.TypeName;
		
		SelectionForOCR = Undefined;
		Selection = GetSelectionForDumpWithRestrictions(Rule, SelectionForOCR, Properties);
		
		IsNotReferenceType = TypeName =  "InformationRegister" Or TypeName = "AccountingRegister";
		
		While Selection.Next() Do
			
			If IsNotReferenceType Then
				ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
			Else					
				ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
			EndIf;
			
		EndDo;
		
	// Standard selection without filter.
	ElsIf (Rule.DataSelectionVariant = "StandardSelection") Then
		
		Properties	= Managers[Rule.SelectionObject];
		TypeName		= Properties.TypeName;
		
		If TypeName = "Constants" Then
			
			DumpConstantsSet(Rule, Properties, OutgoingData);
			
		Else
			
			IsNotReferenceType = TypeName =  "InformationRegister" 
				OR TypeName = "AccountingRegister";
			
			If IsNotReferenceType Then
					
				SelectAllFields = DefineNeedToSelectAllFields(Rule);
				
			Else
				
				// receive only ref
				SelectAllFields = Rule.SelectExportDataInSingleQuery;	
				
			EndIf;
			
			Selection = GetSelectionForDataDumpClear(Properties, TypeName, , , SelectAllFields);
			SelectionForOCR = ?(Rule.SelectExportDataInSingleQuery, Selection, Undefined);
			
			If Selection = Undefined Then
				Return;
			EndIf;
			
			While Selection.Next() Do
				
				If IsNotReferenceType Then
					
					ExportSelectionObject(Selection, Rule, Properties, OutgoingData);
					
				Else
					
					ExportSelectionObject(Selection.Ref, Rule, Properties, OutgoingData, SelectionForOCR);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	ElsIf Rule.DataSelectionVariant = "ArbitraryAlgorithm" Then

		If DataSelection <> Undefined Then
			
			Selection = GetSelectionForDumpByArbitraryAlgorithm(DataSelection);
			
			If Selection <> Undefined Then
				
				While Selection.Next() Do
					
					ExportSelectionObject(Selection, Rule, , OutgoingData);
					
				EndDo;
				
			Else
				
				For Each Object IN DataSelection Do
					
					ExportSelectionObject(Object, Rule, , OutgoingData);
					
				EndDo;
				
			EndIf;
			
		EndIf;
			
	EndIf;

	
	// Handler AfterDataProcessor

	If Not IsBlankString(Rule.AfterProcessing) Then
	
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Rule, "AfterProcessing"));
				
			Else
				
				Execute(Rule.AfterProcessing);
				
			EndIf;
			
		Except
			
			WriteInformationAboutErrorDDRHandlers(32, ErrorDescription(), Rule.Name, "AfterProcessDataExport");
			
		EndTry;
		
	 EndIf;	
	
EndProcedure

// Bypasses data export rules tree and exports.
//
// Parameters:
//  Rows         - Values tree strings collection.
// 
Procedure ProcessDumpRules(Rows, ExchangePlanNodesAndExportRowsMap)
	
	For Each ExportRule IN Rows Do
		
		If ExportRule.Enable = 0 Then
			
			Continue;
			
		EndIf; 
		
		If (ExportRule.ExchangeNodeRef <> Undefined 
				AND Not ExportRule.ExchangeNodeRef.IsEmpty()) Then
			
			ExportRuleArray = ExchangePlanNodesAndExportRowsMap.Get(ExportRule.ExchangeNodeRef);
			
			If ExportRuleArray = Undefined Then
				
				ExportRuleArray = New Array();	
				
			EndIf;
			
			ExportRuleArray.Add(ExportRule);
			
			ExchangePlanNodesAndExportRowsMap.Insert(ExportRule.ExchangeNodeRef, ExportRuleArray);
			
			Continue;
			
		EndIf;

		If ExportRule.IsFolder Then
			
			ProcessDumpRules(ExportRule.Rows, ExchangePlanNodesAndExportRowsMap);
			Continue;
			
		EndIf;
		
		DumpDataByRule(ExportRule);
		
	EndDo; 
	
EndProcedure

Function CopyArrayOfDumpRules(SourceArray)
	
	ResultingArray = New Array();
	
	For Each Item IN SourceArray Do
		
		ResultingArray.Add(Item);	
		
	EndDo;
	
	Return ResultingArray;
	
EndFunction

Function FindRowOfTreeOfDumpRulesByDumpType(RowArray, ExportType)
	
	For Each ArrayRow IN RowArray Do
		
		If ArrayRow.SelectionObject = ExportType Then
			
			Return ArrayRow;
			
		EndIf;
			
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure DeleteRowOfDumpRulesTreeByDumpTypeFromArray(RowArray, ItemToDelete)
	
	Counter = RowArray.Count() - 1;
	While Counter >= 0 Do
		
		ArrayRow = RowArray[Counter];
		
		If ArrayRow = ItemToDelete Then
			
			RowArray.Delete(Counter);
			Return;
			
		EndIf; 
		
		Counter = Counter - 1;	
		
	EndDo;
	
EndProcedure

Procedure GetLineOfDumpRulesByExchangeObject(Data, LastObjectMetadata, ExportObjectMetadata, 
	LastExportRuleRow, CurrentExportRuleRow, TempConversionRuleArray, ObjectForUnloadRules, 
	ExportingRegister, ExportingConstants, ConstantsWereExported)
	
	CurrentExportRuleRow = Undefined;
	ObjectForUnloadRules = Undefined;
	ExportingRegister = False;
	ExportingConstants = False;
	
	If LastObjectMetadata = ExportObjectMetadata
		AND LastExportRuleRow = Undefined Then
		
		Return;
		
	EndIf;
	
	DataStructure = ManagersForExchangePlans[ExportObjectMetadata];
	
	If DataStructure = Undefined Then
		
		ExportingConstants = Metadata.Constants.Contains(ExportObjectMetadata);
		
		If ConstantsWereExported 
			OR Not ExportingConstants Then
			
			Return;
			
		EndIf;
		
		// You should find rule for constants.
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindRowOfTreeOfDumpRulesByDumpType(TempConversionRuleArray, Type("ConstantsSet"));
			
		Else
			
			CurrentExportRuleRow = LastExportRuleRow;
			
		EndIf;
		
		Return;
		
	EndIf;
	
	If DataStructure.IsReferenceType = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindRowOfTreeOfDumpRulesByDumpType(TempConversionRuleArray, DataStructure.ReferenceType);
			
		Else
			
			CurrentExportRuleRow = LastExportRuleRow;
			
		EndIf;
		
		ObjectForUnloadRules = Data.Ref;
		
	ElsIf DataStructure.ThisIsRegister = True Then
		
		If LastObjectMetadata <> ExportObjectMetadata Then
		
			CurrentExportRuleRow = FindRowOfTreeOfDumpRulesByDumpType(TempConversionRuleArray, DataStructure.ReferenceType);
			
		Else
			
			CurrentExportRuleRow = LastExportRuleRow;	
			
		EndIf;
		
		ObjectForUnloadRules = Data;
		
		ExportingRegister = True;
		
	EndIf;
	
EndProcedure

Function RunDataModifiedForExchangeNodeDump(ExchangeNode, ConversionRuleArray, StructureForChangeRecordDeletion)
	
	StructureForChangeRecordDeletion.Insert("OCRArray", Undefined);
	StructureForChangeRecordDeletion.Insert("MessageNo", Undefined);
	
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	
	// Create a new message
	WriteMessage = ExchangePlans.CreateMessageWriter();
		
	WriteMessage.BeginWrite(XMLWriter, ExchangeNode);
	
	// Count the number of written objects.
	FoundObjectToWriteCount = 0;
	
	// start transaction
	If UseTransactionsOnExportForExchangePlans Then
		BeginTransaction();
	EndIf;
	
	LastMetadataObject = Undefined;
	LastExportRuleRow = Undefined;
	
	CurrentMetadataObject = Undefined;
	CurrentExportRuleRow = Undefined;
	
	OutgoingData = Undefined;
	
	TempConversionRuleArray = CopyArrayOfDumpRules(ConversionRuleArray);
	
	Cancel			= False;
	OutgoingData	= Undefined;
	DataSelection	= Undefined;
	
	ObjectForUnloadRules = Undefined;
	ConstantsWereExported = False;
	
	Try
	
		// Get the changed data selection.
		MetadataToExportArray = New Array();
				
		// Expand array only using metadata that has export rules by it - , leave other metadata.
		For Each ExportRuleRow IN TempConversionRuleArray Do
			
			DDRMetadata = Metadata.FindByType(ExportRuleRow.SelectionObject);
			MetadataToExportArray.Add(DDRMetadata);
			
		EndDo;
		
		ChangeSelection = ExchangePlans.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo, MetadataToExportArray);
		
		StructureForChangeRecordDeletion.MessageNo = WriteMessage.MessageNo;
		
		While ChangeSelection.Next() Do
					
			Data = ChangeSelection.Get();
			FoundObjectToWriteCount = FoundObjectToWriteCount + 1;
			
			ExportDataType = TypeOf(Data); 
			
			Delete = (ExportDataType = deObjectDeletionType);
			
			// do not process deletion
			If Delete Then
				Continue;
			EndIf;
			
			CurrentMetadataObject = Data.Metadata();
			
			// Work with data received from
			// exchange node by data determine conversion rule and export data.
			
			ExportingRegister = False;
			ExportingConstants = False;
			
			GetLineOfDumpRulesByExchangeObject(Data, LastMetadataObject, CurrentMetadataObject,
				LastExportRuleRow, CurrentExportRuleRow, TempConversionRuleArray, ObjectForUnloadRules,
				ExportingRegister, ExportingConstants, ConstantsWereExported);
				
			If LastMetadataObject <> CurrentMetadataObject Then
				
				// after processing
				If LastExportRuleRow <> Undefined Then
			
					If Not IsBlankString(LastExportRuleRow.AfterProcessing) Then
					
						Try
							
							If HandlersDebugModeFlag Then
								
								Execute(GetHandlerCallString(LastExportRuleRow, "AfterProcessing"));
								
							Else
								
								Execute(LastExportRuleRow.AfterProcessing);
								
							EndIf;
							
						Except
							
							WriteInformationAboutErrorDDRHandlers(32, ErrorDescription(), LastExportRuleRow.Name, "AfterProcessDataExport");
							
						EndTry;
						
					EndIf;
					
				EndIf;
				
				// before processing
				If CurrentExportRuleRow <> Undefined Then
					
					If CommentObjectProcessingFlag Then
						
						MessageString = PlaceParametersIntoString(NStr("en='Data export rule: %1 (%2)';ru='Правило выгрузки данных: %1 (%2)'"),
							TrimAll(CurrentExportRuleRow.Name), TrimAll(CurrentExportRuleRow.Description));
						WriteInExecutionProtocol(MessageString, , False, , 4);
						
					EndIf;
					
					// Handler BeforeDataProcessor
					Cancel			= False;
					OutgoingData	= Undefined;
					DataSelection	= Undefined;
					
					If Not IsBlankString(CurrentExportRuleRow.BeforeProcess) Then
					
						Try
							
							If HandlersDebugModeFlag Then
								
								Execute(GetHandlerCallString(CurrentExportRuleRow, "BeforeProcess"));
								
							Else
								
								Execute(CurrentExportRuleRow.BeforeProcess);
								
							EndIf;
							
						Except
							
							WriteInformationAboutErrorDDRHandlers(31, ErrorDescription(), CurrentExportRuleRow.Name, "BeforeProcessDataExport");
							
						EndTry;
						
					EndIf;
					
					If Cancel Then
						
						// Delete rule from rules array.
						CurrentExportRuleRow = Undefined;
						DeleteRowOfDumpRulesTreeByDumpTypeFromArray(TempConversionRuleArray, CurrentExportRuleRow);
						ObjectForUnloadRules = Undefined;
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// There is a rule according to which you should export data.
			If CurrentExportRuleRow <> Undefined Then
				
				If ExportingRegister Then
					
					For Each RegisterLine IN ObjectForUnloadRules Do
						ExportSelectionObject(RegisterLine, CurrentExportRuleRow, , OutgoingData);
					EndDo;
					
				ElsIf ExportingConstants Then
					
					Properties	= Managers[CurrentExportRuleRow.SelectionObject];
					DumpConstantsSet(CurrentExportRuleRow, Properties, OutgoingData);
					
				Else
				
					ExportSelectionObject(ObjectForUnloadRules, CurrentExportRuleRow, , OutgoingData);
				
				EndIf;
				
			EndIf;
			
			LastMetadataObject = CurrentMetadataObject;
			LastExportRuleRow = CurrentExportRuleRow; 
			
			If CountProcessedObjectsForRefreshStatus > 0 
				AND FoundObjectToWriteCount % CountProcessedObjectsForRefreshStatus = 0 Then
				
				Try
					MetadataName = CurrentMetadataObject.FullName();
				Except
					MetadataName = "";
				EndTry;
				
			EndIf;
			
			If UseTransactionsOnExportForExchangePlans 
				AND (ItemsCountInTransactionOnExportForExchangePlans > 0)
				AND (FoundObjectToWriteCount = ItemsCountInTransactionOnExportForExchangePlans) Then
				
				// Close the staging transaction and open a new one.
				CommitTransaction();
				BeginTransaction();
				
				FoundObjectToWriteCount = 0;
			EndIf;
			
		EndDo;
		
		If UseTransactionsOnExportForExchangePlans Then
			CommitTransaction();
		EndIf;
		
		// Finish writing the message
		WriteMessage.EndWrite();
		
		XMLWriter.Close();
		
		// event after processing
		If LastExportRuleRow <> Undefined Then
		
			If Not IsBlankString(LastExportRuleRow.AfterProcessing) Then
			
				Try
					
					If HandlersDebugModeFlag Then
						
						Execute(GetHandlerCallString(LastExportRuleRow, "AfterProcessing"));
						
					Else
						
						Execute(LastExportRuleRow.AfterProcessing);
						
					EndIf;
					
				Except
					
					WriteInformationAboutErrorDDRHandlers(32, ErrorDescription(), LastExportRuleRow.Name, "AfterProcessDataExport");
					
				EndTry;
				
			EndIf;
			
		EndIf;
		
	Except
		
		If UseTransactionsOnExportForExchangePlans Then
			RollbackTransaction();
		EndIf;
		
		LR = GetProtocolRecordStructure(72, ErrorDescription());
		LR.ExchangePlanNode  = ExchangeNode;
		LR.Object = Data;
		LR.ObjectType = ExportDataType;
		
		ErrorMessageString = WriteInExecutionProtocol(72, LR, True);
						
		XMLWriter.Close();
		
		Return False;
		
	EndTry;
	
	StructureForChangeRecordDeletion.OCRArray = TempConversionRuleArray;
	
	Return Not Cancel;
	
EndFunction

Function ProcessDumpForExchangePlans(NodeAndExportRuleMap, StructureForChangeRecordDeletion)
	
	SuccessfulExport = True;
	
	For Each MapRow IN NodeAndExportRuleMap Do
		
		ExchangeNode = MapRow.Key;
		ConversionRuleArray = MapRow.Value;
		
		LocalStructureForChangeRecordDeletion = New Structure();
		
		CurrentSuccessfulExport = RunDataModifiedForExchangeNodeDump(ExchangeNode, ConversionRuleArray, LocalStructureForChangeRecordDeletion);
		
		SuccessfulExport = SuccessfulExport AND CurrentSuccessfulExport;
		
		If LocalStructureForChangeRecordDeletion.OCRArray <> Undefined
			AND LocalStructureForChangeRecordDeletion.OCRArray.Count() > 0 Then
			
			StructureForChangeRecordDeletion.Insert(ExchangeNode, LocalStructureForChangeRecordDeletion);	
			
		EndIf;
		
	EndDo;
	
	Return SuccessfulExport;
	
EndFunction

Procedure ProcessChangeOfRegistrationForExchangeNodes(NodeAndExportRuleMap)
	
	For Each Item IN NodeAndExportRuleMap Do
	
		If TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = 0 Then
			
			Return;
			
		ElsIf TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = 1 Then
			
			// Cancel registration for all changes that took place in the exchange plan.
			ExchangePlans.DeleteChangeRecords(Item.Key, Item.Value.MessageNo);
			
		ElsIf TypeOfChangesRegistrationDeletionForExchangeNodesAfterDump = 2 Then	
			
			// Delete changes only for exported objects metadata of the first level.
			
			For Each ExportedOCR IN Item.Value.OCRArray Do
				
				Try
					
					Rule = Rules[ExportedOCR.ConversionRule];
					
					Manager = Managers[Rule.Source];
					
					ExchangePlans.DeleteChangeRecords(Item.Key, Manager.MDObject);	
					
				Except
					
					
				EndTry;
				
			EndDo;
			
		EndIf;
	
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EXPORTED PROCEDURES AND FUNCTIONS

// Opens exchange file, reads file root node attributes according to the exchange format.
//
// Parameters:
//  ReadHeaderOnly - Boolean. if it is True, then file is
//  closed after reading the exchange file header (root node).
//
Procedure OpenImportFile(ReadHeaderOnly=False, ExchangeFileData = "") Export

	If IsBlankString(ExchangeFileName) AND ReadHeaderOnly Then
		StartDate         = "";
		EndDate      = "";
		DataExportDate = "";
		ExchangeRulesVersion = "";
		Comment        = "";
		Return;
	EndIf;


    DataImportFileName = ExchangeFileName;
	
	
	// Identify archive files according to the extension ".zip".
	If Find(ExchangeFileName, ".zip") > 0 Then
		
		DataImportFileName = UnpackZIPFile(ExchangeFileName);		 
		
	EndIf; 
	
	
	ErrorFlag = False;
	ExchangeFile = New XMLReader();

	Try
		If Not IsBlankString(ExchangeFileData) Then
			ExchangeFile.SetString(ExchangeFileData);
		Else
			ExchangeFile.OpenFile(DataImportFileName);
		EndIf;
	Except
		WriteInExecutionProtocol(5);
		Return;
	EndTry;
	
	ExchangeFile.Read();


	mExchangeFileAttributes = New Structure;
	
	
	If ExchangeFile.LocalName = "ExchangeFile" Then
		
		mExchangeFileAttributes.Insert("FormatVersion",            deAttribute(ExchangeFile, deStringType, "FormatVersion"));
		mExchangeFileAttributes.Insert("ExportDate",             deAttribute(ExchangeFile, deDateType,   "ExportDate"));
		mExchangeFileAttributes.Insert("ExportPeriodStart",    deAttribute(ExchangeFile, deDateType,   "ExportPeriodStart"));
		mExchangeFileAttributes.Insert("ExportEndOfPeriod", deAttribute(ExchangeFile, deDateType,   "ExportEndOfPeriod"));
		mExchangeFileAttributes.Insert("SourceConfigurationName", deAttribute(ExchangeFile, deStringType, "SourceConfigurationName"));
		mExchangeFileAttributes.Insert("TargetConfigurationName", deAttribute(ExchangeFile, deStringType, "TargetConfigurationName"));
		mExchangeFileAttributes.Insert("ConversionRuleIDs",      deAttribute(ExchangeFile, deStringType, "ConversionRuleIDs"));
		
		StartDate         = mExchangeFileAttributes.ExportPeriodStart;
		EndDate      = mExchangeFileAttributes.ExportEndOfPeriod;
		DataExportDate = mExchangeFileAttributes.ExportDate;
		Comment        = deAttribute(ExchangeFile, deStringType, "Comment");
		
	Else
		
		WriteInExecutionProtocol(9);
		Return;
		
	EndIf;


	ExchangeFile.Read();
			
	NodeName = ExchangeFile.LocalName;
		
	If NodeName = "ExchangeRules" Then
		ImportExchangeRules(ExchangeFile, "XMLReader");
						
	Else
		ExchangeFile.Close();
		ExchangeFile = New XMLReader();
		Try
			
			If Not IsBlankString(ExchangeFileData) Then
				ExchangeFile.SetString(ExchangeFileData);
			Else
				ExchangeFile.OpenFile(DataImportFileName);
			EndIf;
			
		Except
			
			WriteInExecutionProtocol(5);
			Return;
			
		EndTry;
		
		ExchangeFile.Read();
		
	EndIf; 
	
	mExchangeRulesReadOnImport = True;

	If ReadHeaderOnly Then
		
		ExchangeFile.Close();
		Return;
		
	EndIf;
   
EndProcedure

// Fills in the passed values table with metadata objects types for removal to which
// there is the right of access for removal.
//
Procedure FillListOfTypesAvailableForDeletion(DataTable) Export
	
	DataTable.Clear();
	
	For Each MDObject IN Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "CatalogRef." + MDObject.Name;
		
	EndDo;

	For Each MDObject IN Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "ChartOfCharacteristicTypesRef." + MDObject.Name;
	EndDo;

	For Each MDObject IN Metadata.Documents Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "DocumentRef." + MDObject.Name;
	EndDo;

	For Each MDObject IN Metadata.InformationRegisters Do
		
		If Not AccessRight("Delete", MDObject) Then
			Continue;
		EndIf;
		
		Subordinate		=	(MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		TableRow = DataTable.Add();
		TableRow.Metadata = "InformationRegisterRecord." + MDObject.Name;
		
	EndDo;
	
EndProcedure

// Sets mark state of the subordinate strings of
// the values tree string depending on the current string mark.
//
// Parameters:
//  CurRow      - Values tree string.
// 
Procedure SetMarksOfSubordinateOnes(CurRow, Attribute) Export

	Subordinate = CurRow.Rows;

	If Subordinate.Count() = 0 Then
		Return;
	EndIf;
	
	For Each String IN Subordinate Do
		
		If String.BuilderSettings = Undefined 
			AND Attribute = "UseFilter" Then
			
			String[Attribute] = 0;
			
		Else
			
			String[Attribute] = CurRow[Attribute];
			
		EndIf;
		
		SetMarksOfSubordinateOnes(String, Attribute);
		
	EndDo;
		
EndProcedure

// Sets mark state in the parent strings of
// the values tree string depending on the current string mark.
//
// Parameters:
//  CurRow      - Values tree string.
// 
Procedure SetMarksOfParents(CurRow, Attribute) Export

	Parent = CurRow.Parent;
	If Parent = Undefined Then
		Return;
	EndIf; 

	CurState       = Parent[Attribute];

	EnabledItemsFound  = False;
	DisabledItemsFound = False;

	If Attribute = "UseFilter" Then
		
		For Each String IN Parent.Rows Do
			
			If String[Attribute] = 0 AND 
				String.BuilderSettings <> Undefined Then
				
				DisabledItemsFound = True;
				
			ElsIf String[Attribute] = 1 Then
				EnabledItemsFound  = True;
			EndIf; 
			
			If EnabledItemsFound AND DisabledItemsFound Then
				Break;
			EndIf; 
			
		EndDo;
		
	Else
		
		For Each String IN Parent.Rows Do
			If String[Attribute] = 0 Then
				DisabledItemsFound = True;
			ElsIf String[Attribute] = 1
				OR String[Attribute] = 2 Then
				EnabledItemsFound  = True;
			EndIf; 
			If EnabledItemsFound AND DisabledItemsFound Then
				Break;
			EndIf; 
		EndDo;
		
	EndIf;

	
	If EnabledItemsFound AND DisabledItemsFound Then
		Enable = 2;
	ElsIf EnabledItemsFound AND (NOT DisabledItemsFound) Then
		Enable = 1;
	ElsIf (NOT EnabledItemsFound) AND DisabledItemsFound Then
		Enable = 0;
	ElsIf (NOT EnabledItemsFound) AND (NOT DisabledItemsFound) Then
		Enable = 2;
	EndIf;

	If Enable = CurState Then
		Return;
	Else
		Parent[Attribute] = Enable;
		SetMarksOfParents(Parent, Attribute);
	EndIf; 
	
EndProcedure


Function RefreshMarksOfAllParentsOfDumpRules(ExportRuleTreeRows, MustSetMarks = True)
	
	If ExportRuleTreeRows.Rows.Count() = 0 Then
		
		If MustSetMarks Then
			SetMarksOfParents(ExportRuleTreeRows, "Enable");	
		EndIf;
		
		Return True;
		
	Else
		
		MarksRequired = True;
		
		For Each RuleTreeRow IN ExportRuleTreeRows.Rows Do
			
			SetupResult = RefreshMarksOfAllParentsOfDumpRules(RuleTreeRow, MarksRequired);
			If MarksRequired = True Then
				MarksRequired = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndFunction


Procedure FillPropertiesForSearch(DataStructure, PCR)
	
	For Each FieldsRow IN PCR Do
		
		If FieldsRow.IsFolder Then
						
			If FieldsRow.TargetKind = "TabularSection" 
				OR Find(FieldsRow.TargetKind, "RegisterRecordSet") > 0 Then
				
				RecipientStructureName = FieldsRow.Receiver + ?(FieldsRow.TargetKind = "TabularSection", "TabularSection", "RecordSet");
				
				InternalStructure = DataStructure[RecipientStructureName];
				
				If InternalStructure = Undefined Then
					InternalStructure = New Map();
				EndIf;
				
				DataStructure[RecipientStructureName] = InternalStructure;
				
			Else
				
				InternalStructure = DataStructure;	
				
			EndIf;
			
			FillPropertiesForSearch(InternalStructure, FieldsRow.GroupRules);
									
		Else
			
			If IsBlankString(FieldsRow.ReceiverType)	Then
				
				Continue;
				
			EndIf;
			
			DataStructure[FieldsRow.Receiver] = FieldsRow.ReceiverType;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteNotNeededItemsFromMap(DataStructure)
	
	For Each Item IN DataStructure Do
		
		If TypeOf(Item.Value) = deMapType Then
			
			DeleteNotNeededItemsFromMap(Item.Value);
			
			If Item.Value.Count() = 0 Then
				DataStructure.Delete(Item.Key);
			EndIf;
			
		EndIf;		
		
	EndDo;		
	
EndProcedure

Procedure FillInformationByReceiverDataTypes(DataStructure, Rules)
	
	For Each String IN Rules Do
		
		If IsBlankString(String.Receiver) Then
			Continue;
		EndIf;
		
		StructureData = DataStructure[String.Receiver];
		If StructureData = Undefined Then
			
			StructureData = New Map();
			DataStructure[String.Receiver] = StructureData;
			
		EndIf;
		
		// Bypass search fields and PCR and remember data types.
		FillPropertiesForSearch(StructureData, String.SearchProperties);
				
		// Properties
		FillPropertiesForSearch(StructureData, String.Properties);
		
	EndDo;
	
	DeleteNotNeededItemsFromMap(DataStructure);	
	
EndProcedure

Procedure CreateStringWithTypesOfProperties(XMLWriter, PropertyTypes)
	
	If TypeOf(PropertyTypes.Value) = deMapType Then
		
		If PropertyTypes.Value.Count() = 0 Then
			Return;
		EndIf;
		
		XMLWriter.WriteStartElement(PropertyTypes.Key);
		
		For Each Item IN PropertyTypes.Value Do
			CreateStringWithTypesOfProperties(XMLWriter, Item);
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	Else		
		
		deWriteItem(XMLWriter, PropertyTypes.Key, PropertyTypes.Value);
		
	EndIf;
	
EndProcedure

Function CreateStringWithTypesForReceiver(DataStructure)
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteStartElement("DataTypeInfo");	
	
	For Each String IN DataStructure Do
		
		XMLWriter.WriteStartElement("DataType");
		SetAttribute(XMLWriter, "Name", String.Key);
		
		For Each SubordinationRow IN String.Value Do
			
			CreateStringWithTypesOfProperties(XMLWriter, SubordinationRow);	
			
		EndDo;
		
		XMLWriter.WriteEndElement();
		
	EndDo;	
	
	XMLWriter.WriteEndElement();
	
	ResultRow = XMLWriter.Close();
	Return ResultRow;
	
EndFunction

Procedure ImportOneDataType(ExchangeRules, TypeMap, LocalItemName)
	
	NodeName = LocalItemName;
	
	ExchangeRules.Read();
	
	If (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
		
		ExchangeRules.Read();
		Return;
		
	ElsIf ExchangeRules.NodeType = odNodeTypeXML_StartElement Then
			
		// this is a new item
		NewMap = New Map;
		TypeMap.Insert(NodeName, NewMap);
		
		ImportOneDataType(ExchangeRules, NewMap, ExchangeRules.LocalName);			
		ExchangeRules.Read();
		
	Else
		TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
		ExchangeRules.Read();
	EndIf;	
	
	ImportTypesMappingForOneType(ExchangeRules, TypeMap);
	
EndProcedure

Procedure ImportTypesMappingForOneType(ExchangeRules, TypeMap)
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
			
		    Break;
			
		EndIf;
		
		// read the item beginning
		ExchangeRules.Read();
		
		If ExchangeRules.NodeType = odNodeTypeXML_StartElement Then
			
			// this is a new item
			NewMap = New Map;
			TypeMap.Insert(NodeName, NewMap);
			
			ImportOneDataType(ExchangeRules, NewMap, ExchangeRules.LocalName);			
			
		Else
			TypeMap.Insert(NodeName, Type(ExchangeRules.Value));
			ExchangeRules.Read();
		EndIf;	
		
	EndDo;	
	
EndProcedure

Procedure ImportInformationAboutDataTypes()
	
	While ExchangeFile.Read() Do
		
		NodeName = ExchangeFile.LocalName;
		
		If NodeName = "DataType" Then
			
			TypeName = deAttribute(ExchangeFile, deStringType, "Name");
			
			TypeMap = New Map;
			mDataTypeMapForImport.Insert(Type(TypeName), TypeMap);

			ImportTypesMappingForOneType(ExchangeFile, TypeMap);	
			
		ElsIf (NodeName = "DataTypeInfo") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
			
			Break;
			
		EndIf;
		
	EndDo;	
	
EndProcedure

Procedure ImportDataEchangeParameterValues()
	
	Name = deAttribute(ExchangeFile, deStringType, "Name");
		
	PropertyType = GetPropertyTypeByAdditionalInformation(Undefined, Name);
	
	Value = ReadProperty(PropertyType);
	
	Parameters.Insert(Name, Value);	
	
	AfterParameterImportAlgorithm = "";
	If EventsAfterParameterImport.Property(Name, AfterParameterImportAlgorithm)
		AND Not IsBlankString(AfterParameterImportAlgorithm) Then
		
		If HandlersDebugModeFlag Then
			
			Raise NStr("en='""After parameter import"" handler debugging is not supported.';ru='Отладка обработчика ""После загрузки параметра"" не поддерживается.'");
			
		Else
			
			Execute(AfterParameterImportAlgorithm);
			
		EndIf;
		
	EndIf;
		
EndProcedure

Function GetFromTextHandlerValue(ExchangeRules)
	
	HandlerText = deItemValue(ExchangeRules, deStringType);
	
	If Find(HandlerText, Chars.LF) = 0 Then
		Return HandlerText;
	EndIf;
	
	HandlerText = StrReplace(HandlerText, Char(10), Chars.LF);
	
	Return HandlerText;
	
EndFunction

// Imports exchange rules according to the format.
//
// Parameters:
//  Source        - Object from which exchange rules are imported;
//  SourceType    - String specifying source type: "XMLFile", "XMLReading", "String".
// 
Procedure ImportExchangeRules(Source="", SourceType="XMLFile") Export
	
	InitializeManagersAndMessages();
	
	HasBeforeObjectExportGlobalHandler    = False;
	HasAfterObjectExportGlobalHandler     = False;
	
	HasBeforeConvertObjectGlobalHandler = False;

	HasBeforeObjectImportGlobalHandler    = False;
	HasAftertObjectImportGlobalHandler     = False;
	
	CreateConversionStructure();
	
	mPropertyConversionRuleTable = New ValueTable;
	PropertiesConversionRulesTableInitialization(mPropertyConversionRuleTable);
	SupplementSystemTablesWithColumns();
	
	// Embeded exchange rules may be selected (one of the templates).
	
	ExchangeRuleTempFileName = "";
	If IsBlankString(Source) Then
		
		Source = ExchangeRulesFilename;
		If mExchangeRuleTemplateList.FindByValue(Source) <> Undefined Then
			For Each Template IN ThisObject.Metadata().Templates Do
				If Template.Synonym = Source Then
					Source = Template.Name;
					Break;
				EndIf; 
			EndDo; 
			ExchangeRuleTemplate              = GetTemplate(Source);
			UUID        = New UUID();
			ExchangeRuleTempFileName = TempFilesDir() + UUID + ".xml";
			ExchangeRuleTemplate.Write(ExchangeRuleTempFileName);
			Source = ExchangeRuleTempFileName;
		EndIf;
		
	EndIf;

	
	If SourceType="XMLFile" Then
		
		If IsBlankString(Source) Then
			WriteInExecutionProtocol(12);
			Return; 
		EndIf;
		
		File = New File(Source);
		If Not File.Exist() Then
			WriteInExecutionProtocol(3);
			Return; 
		EndIf;
		
		RuleFilePacked = (File.Extension = ".zip");
		
		If RuleFilePacked Then
			
			// rules file unpack
			Source = UnpackZIPFile(Source);
						
		EndIf;
		
		ExchangeRules = New XMLReader();
		ExchangeRules.OpenFile(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="String" Then
		
		ExchangeRules = New XMLReader();
		ExchangeRules.SetString(Source);
		ExchangeRules.Read();
		
	ElsIf SourceType="XMLReader" Then
		
		ExchangeRules = Source;
		
	EndIf; 
	

	If Not ((ExchangeRules.LocalName = "ExchangeRules") AND (ExchangeRules.NodeType = odNodeTypeXML_StartElement)) Then
		WriteInExecutionProtocol(6);
		Return;
	EndIf;


	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.Indent = True;
	XMLWriter.WriteStartElement("ExchangeRules");
	

	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		// Conversion attributes
		If NodeName = "FormatVersion" Then
			Value = deItemValue(ExchangeRules, deStringType);
			Conversion.Insert("FormatVersion", Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "ID" Then
			Value = deItemValue(ExchangeRules, deStringType);
			Conversion.Insert("ID",                   Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Description" Then
			Value = deItemValue(ExchangeRules, deStringType);
			Conversion.Insert("Description",         Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "CreationDateTime" Then
			Value = deItemValue(ExchangeRules, deDateType);
			Conversion.Insert("CreationDateTime",    Value);
			deWriteItem(XMLWriter, NodeName, Value);
			ExchangeRulesVersion = Conversion.CreationDateTime;
		ElsIf NodeName = "Source" Then
			Value = deItemValue(ExchangeRules, deStringType);
			Conversion.Insert("Source",             Value);
			deWriteItem(XMLWriter, NodeName, Value);
		ElsIf NodeName = "Receiver" Then
			
			TargetPlatformVersion = ExchangeRules.GetAttribute ("PlatformVersion");
			TargetPlatform = DefinePlatformByReceiverPlatformVersion(TargetPlatformVersion);
			
			Value = deItemValue(ExchangeRules, deStringType);
			Conversion.Insert("Receiver",             Value);
			deWriteItem(XMLWriter, NodeName, Value);
			
		ElsIf NodeName = "DeleteMappedObjectsFromTargetOnDeleteFromSource" Then
			deIgnore(ExchangeRules);
		
		ElsIf NodeName = "Comment" Then
			deIgnore(ExchangeRules);
			
		ElsIf NodeName = "MainExchangePlan" Then
			deIgnore(ExchangeRules);

		ElsIf NodeName = "Parameters" Then
			ImportParameters(ExchangeRules, XMLWriter)

		// Conversion events
		
		ElsIf NodeName = "" Then
			
		ElsIf NodeName = "AfterExchangeRuleImport" Then
			Conversion.Insert("AfterExchangeRuleImport", GetFromTextHandlerValue(ExchangeRules));	
			
		ElsIf NodeName = "BeforeDataExport" Then
			Conversion.Insert("BeforeDataExport", GetFromTextHandlerValue(ExchangeRules));
			
		ElsIf NodeName = "AfterDataExport" Then
			Conversion.Insert("AfterDataExport",  GetFromTextHandlerValue(ExchangeRules));

		ElsIf NodeName = "BeforeObjectExport" Then
			Conversion.Insert("BeforeObjectExport", GetFromTextHandlerValue(ExchangeRules));
			HasBeforeObjectExportGlobalHandler = Not IsBlankString(Conversion.BeforeObjectExport);

		ElsIf NodeName = "AfterObjectExport" Then
			Conversion.Insert("AfterObjectExport", GetFromTextHandlerValue(ExchangeRules));
			HasAfterObjectExportGlobalHandler = Not IsBlankString(Conversion.AfterObjectExport);

		ElsIf NodeName = "BeforeObjectImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("BeforeObjectImport", Value);
				HasBeforeObjectImportGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AftertObjectImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("AftertObjectImport", Value);
				HasAftertObjectImportGlobalHandler = Not IsBlankString(Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "BeforeObjectConversion" Then
			Conversion.Insert("BeforeObjectConversion", GetFromTextHandlerValue(ExchangeRules));
			HasBeforeConvertObjectGlobalHandler = Not IsBlankString(Conversion.BeforeObjectConversion);
			
		ElsIf NodeName = "BeforeDataImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.BeforeDataImport = Value;
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterDataImport" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.AfterDataImport = Value;
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterParametersImport" Then
			Conversion.Insert("AfterParametersImport", GetFromTextHandlerValue(ExchangeRules));
			
		ElsIf NodeName = "BeforeSendDeletionInfo" Then
			Conversion.Insert("BeforeSendDeletionInfo",  deItemValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "BeforeGetChangedObjects" Then
			Conversion.Insert("BeforeGetChangedObjects", deItemValue(ExchangeRules, deStringType));
			
		ElsIf NodeName = "OnGetDeletionInfo" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("OnGetDeletionInfo", Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;
			
		ElsIf NodeName = "AfterGetExchangeNodeDetails" Then
			
			Value = GetFromTextHandlerValue(ExchangeRules);
			
			If ExchangeMode = "Import" Then
				
				Conversion.Insert("AfterGetExchangeNodeDetails", Value);
				
			Else
				
				deWriteItem(XMLWriter, NodeName, Value);
				
			EndIf;

		// Rules
		
		ElsIf NodeName = "DataUnloadRules" Then
		
 			If ExchangeMode = "Import" Then
				deIgnore(ExchangeRules);
			Else
				ImportDumpRules(ExchangeRules);
 			EndIf; 
			
		ElsIf NodeName = "ObjectConversionRules" Then
			ImportConversionRules(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "DataClearingRules" Then
			ImportClearRules(ExchangeRules, XMLWriter)
			
		ElsIf NodeName = "ObjectRegistrationRules" Then
			deIgnore(ExchangeRules); // Export objects registration rules using another data processor.
			
		// Algorithms / Queries / DataProcessors
		
		ElsIf NodeName = "Algorithms" Then
			ImportAlgorithms(ExchangeRules, XMLWriter);
			
		ElsIf NodeName = "Queries" Then
			ImportQueries(ExchangeRules, XMLWriter);

		ElsIf NodeName = "DataProcessors" Then
			ImportDataProcessors(ExchangeRules, XMLWriter);
			
		// Exit
		ElsIf (NodeName = "ExchangeRules") AND (ExchangeRules.NodeType = odNodeTypeXML_EndElement) Then
		
			If ExchangeMode <> "Import" Then
				ExchangeRules.Close();
			EndIf;
			Break;

			
		// Format error
		Else
		    RecordStructure = New Structure("NodeName", NodeName);
			WriteInExecutionProtocol(7, RecordStructure);
			Return;
		EndIf;
	EndDo;


	XMLWriter.WriteEndElement();
	mXMLRules = XMLWriter.Close();
	
	For Each ExportRuleRow IN UnloadRulesTable.Rows Do
		RefreshMarksOfAllParentsOfDumpRules(ExportRuleRow, True);
	EndDo;
	
	// Delete rules temporary file.
	If Not IsBlankString(ExchangeRuleTempFileName) Then
		Try
 			DeleteFiles(ExchangeRuleTempFileName);
		Except 
		EndTry;
	EndIf;
	
	If SourceType="XMLFile"
		AND RuleFilePacked Then
		
		Try
			DeleteFiles(Source);
		Except 
		EndTry;	
		
	EndIf;
	
	// Additionally information on the receiver data types is required for fast data import.
	DataStructure = New Map();
	FillInformationByReceiverDataTypes(DataStructure, ConversionRulesTable);
	
	mTypesForTargetString = CreateStringWithTypesForReceiver(DataStructure);
	
	// Call an event after you import exchange rules.
	AfterExchangeRuleImportEventText = "";
	If Conversion.Property("AfterExchangeRuleImport", AfterExchangeRuleImportEventText)
		AND Not IsBlankString(AfterExchangeRuleImportEventText) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Raise NStr("en='""After exchange rules import"" handler debugging is not supported.';ru='Отладка обработчика ""После загрузки правил обмена"" не поддерживается.'");
				
			Else
				
				Execute(AfterExchangeRuleImportEventText);
				
			EndIf;
			
		Except
			
			Text = NStr("en='Handler: ""AfterExchangeRulesImport"": %1';ru='Обработчик: ""ПослеЗагрузкиПравилОбмена"": %1'");
			Text = PlaceParametersIntoString(Text, BriefErrorDescription(ErrorInfo()));
			
			MessageToUser(Text);
			
		EndTry;
		
	EndIf;
	
EndProcedure


Procedure ProcessNewItemReadEnding(LastImportObject)
	
	mImportedObjectCounter = 1 + mImportedObjectCounter;
				
	If mImportedObjectCounter % CountProcessedObjectsForRefreshStatus = 0 Then
		
		If LastImportObject <> Undefined Then
			
			ImportObjectString = ", Object: " + String(TypeOf(LastImportObject)) + "  " + String(LastImportObject);
								
		Else
			
			ImportObjectString = "";
			
		EndIf;
		
	EndIf;
	
	If RememberImportedObjects
		AND mImportedObjectCounter % 100 = 0 Then
				
		If ImportedObjects.Count() > ImportedObjectToStoreCount Then
			ImportedObjects.Clear();
		EndIf;
				
	EndIf;
	
	If mImportedObjectCounter % 100 = 0
		AND mNotWrittenObjectGlobalStack.Count() > 100 Then
		
		WriteNotRecordedObjects();
		
	EndIf;
	
	If UseTransactions
		AND ObjectsCountForTransactions > 0 
		AND mImportedObjectCounter % ObjectsCountForTransactions = 0 Then
		
		CommitTransaction();
		BeginTransaction();
		
	EndIf;	

EndProcedure

// Sequentially reads exchange message file and writes data to the infobase.
//
// Parameters:
//  ErrorInfoResultString - String - resulting string with error information.
// 
Procedure ReadData(ErrorInfoResultString = "") Export
	
	Try
	
		While ExchangeFile.Read() Do
			
			NodeName = ExchangeFile.LocalName;
			
			If NodeName = "Object" Then
				
				LastImportObject = ReadObject();
				
				ProcessNewItemReadEnding(LastImportObject);
				
			ElsIf NodeName = "ParameterValue" Then	
				
				ImportDataEchangeParameterValues();
				
			ElsIf NodeName = "AfterParameterExportAlgorithm" Then	
				
				Cancel = False;
				CancelReason = "";
				
				AlgorithmText = deItemValue(ExchangeFile, deStringType);
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlersDebugModeFlag Then
							
							Raise NStr("en='""After parameters import"" handler debugging is not supported.';ru='Отладка обработчика ""После загрузки параметров"" не поддерживается.'");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
						If Cancel = True Then
							
							If Not IsBlankString(CancelReason) Then
								ExceptionString = PlaceParametersIntoString(NStr("en='Data load canceled because: %1';ru='Загрузка данных отменена по причине: %1'"), CancelReason);
								Raise ExceptionString;
							Else
								Raise NStr("en='Data import is canceled';ru='Загрузка данных отменена'");
							EndIf;
							
						EndIf;
						
					Except
												
						LR = GetProtocolRecordStructure(75, ErrorDescription());
						LR.Handler     = "AfterParametersImport";
						ErrorMessageString = WriteInExecutionProtocol(75, LR, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;				
				
			ElsIf NodeName = "Algorithm" Then
				
				AlgorithmText = deItemValue(ExchangeFile, deStringType);
				
				If Not IsBlankString(AlgorithmText) Then
				
					Try
						
						If HandlersDebugModeFlag Then
							
							Raise NStr("en='Global algorithm debugging is not supported.';ru='Отладка глобального алгоритма не поддерживается.'");
							
						Else
							
							Execute(AlgorithmText);
							
						EndIf;
						
					Except
						
						LR = GetProtocolRecordStructure(39, ErrorDescription());
						LR.Handler     = "ExchangeFileAlgorithm";
						ErrorMessageString = WriteInExecutionProtocol(39, LR, True);
						
						If Not DebugModeFlag Then
							Raise ErrorMessageString;
						EndIf;
						
					EndTry;
					
				EndIf;
				
			ElsIf NodeName = "ExchangeRules" Then
				
				mExchangeRulesReadOnImport = True;
				
				If ConversionRulesTable.Count() = 0 Then
					ImportExchangeRules(ExchangeFile, "XMLReader");
				Else
					deIgnore(ExchangeFile);
				EndIf;
				
			ElsIf NodeName = "DataTypeInfo" Then
				
				ImportInformationAboutDataTypes();
				
			ElsIf (NodeName = "ExchangeFile") AND (ExchangeFile.NodeType = odNodeTypeXML_EndElement) Then
				
			Else
				RecordStructure = New Structure("NodeName", NodeName);
				WriteInExecutionProtocol(9, RecordStructure);
			EndIf;
			
		EndDo;
		
	Except
		
		ErrorString = PlaceParametersIntoString(NStr("en='Error when importing the files: %1';ru='Ошибка при загрузке данных: %1'"), ErrorDescription());
		
		ErrorInfoResultString = WriteInExecutionProtocol(ErrorString, Undefined, True, , , True);
		
		FinishExchangeProtocolLogging();
		ExchangeFile.Close();
		Return;
		
	EndTry;
	
EndProcedure

// Before you start reading data from a
// file, initialize variables, import exchange rules
// from data file, open a transaction for
// data writing to IB, execute required event handlers.
// 
// Parameters:
//  DataRow - attachment file name for data import or XML-string containing data for import.
// 
//  Returns:
//  True - you can import data from file; False - no.
//
Function ExecuteActionsBeforeReadingData(DataRow = "") Export
	
	DataProcessingMode = mDataProcessingModes.Import;

	mExtendedSearchParameterMap       = New Map;
	mConversionRuleMap         = New Map;
	
	Rules.Clear();
	
	InitializeCommentsOnDumpAndDataExport();
	
	ExchangeProtocolInitialization();
	
	ImportPossible = True;
	
	If IsBlankString(DataRow) Then
	
		If IsBlankString(ExchangeFileName) Then
			WriteInExecutionProtocol(15);
			ImportPossible = False;
		EndIf;
	
	EndIf;
	
	// Initialize external data processor with export handlers.
	InitializationOfExternalProcessingOfEventHandlers(ImportPossible, ThisObject);
	
	If Not ImportPossible Then
		Return False;
	EndIf;
	
	MessageString = PlaceParametersIntoString(NStr("en='Import start: %1';ru='Начало загрузки: %1'"), CurrentSessionDate());
	WriteInExecutionProtocol(MessageString, , False, , , True);
	
	If DebugModeFlag Then
		UseTransactions = False;
	EndIf;
	
	If CountProcessedObjectsForRefreshStatus = 0 Then
		
		CountProcessedObjectsForRefreshStatus = 100;
		
	EndIf;
	
	mDataTypeMapForImport = New Map;
	mNotWrittenObjectGlobalStack = New Map;
	
	mImportedObjectCounter = 0;
	ErrorFlag                  = False;
	ImportedObjects          = New Map;
	ImportedGlobalObjects = New Map;

	InitializeManagersAndMessages();
	
	OpenImportFile(,DataRow);
	
	If ErrorFlag Then 
		FinishExchangeProtocolLogging();
		Return False; 
	EndIf;

	// Determine handler interfaces.
	If HandlersDebugModeFlag Then
		
		SupplementRulesWithInterfacesOfHandlers(Conversion, ConversionRulesTable, UnloadRulesTable, FlushRulesTable);
		
	EndIf;
	
	// Handler BeforeDataImport
	Cancel = False;
	
	If Not IsBlankString(Conversion.BeforeDataImport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "BeforeDataImport"));
				
			Else
				
				Execute(Conversion.BeforeDataImport);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteInformationAboutErrorConversionHandlers(22, ErrorDescription(), NStr("en='BeforeDataImport (Conversion)';ru='ПередЗагрузкойДанных (конвертация)'"));
			Cancel = True;
		EndTry;
		
		If Cancel Then // Denial of the data import
			FinishExchangeProtocolLogging();
			ExchangeFile.Close();
			DestructorOfExternalDataProcessorOfEventHandlers();
			Return False;
		EndIf;
		
	EndIf;

	// Clear infobase according to the rules.
	ProcessClearRules(FlushRulesTable.Rows);
		
	If UseTransactions Then
		BeginTransaction();
	EndIf;
	
	Return True;
	
EndFunction

// Procedure executes actions after data import iteration:
// - transaction commit (if needed)
// - close exchange message file
// - execution conversion handler AfterDataImport
// - complete exchange protocol keeping (if needed).
//
// Parameters:
//  No.
// 
Procedure ExecuteActionsAfterDataReadIsCompleted() Export
	
	// Deferred record of things not written in the beginning.
	WriteNotRecordedObjects();
	
	If UseTransactions Then
		CommitTransaction();
	EndIf;

	ExchangeFile.Close();	
	
	// Handler AfterDataImport
	If Not IsBlankString(Conversion.AfterDataImport) Then
		
		Try
			
			If HandlersDebugModeFlag Then
				
				Execute(GetHandlerCallString(Conversion, "AfterDataImport"));
				
			Else
				
				Execute(Conversion.AfterDataImport);
				
			EndIf;
			
		Except
			ErrorMessageString = WriteInformationAboutErrorConversionHandlers(23, ErrorDescription(), NStr("en='AfterDataImport (conversion)';ru='ПослеЗагрузкиДанных (конвертация)'"));
		EndTry;
		
	EndIf;
	
	DestructorOfExternalDataProcessorOfEventHandlers();
	
	WriteInExecutionProtocol(PlaceParametersIntoString(
		NStr("en='Import end: %1';ru='Окончание загрузки: %1'"), CurrentSessionDate()), , False, , , True);
	WriteInExecutionProtocol(PlaceParametersIntoString(
		NStr("en='Objects imported: %1';ru='Загружено объектов: %1'"), mImportedObjectCounter), , False, , , True);
	
	FinishExchangeProtocolLogging();
	
	If ThisIsInteractiveMode Then
		MessageToUser(NStr("en='The data import is completed.';ru='Загрузка данных завершена.'"));
	EndIf;
	
EndProcedure

// Imports data according to the set modes (exchange rules).
//
// Parameters:
//  No.
//
Procedure RunImport() Export
	
	WorkPossible = ExecuteActionsBeforeReadingData();
	
	If Not WorkPossible Then
		Return;
	EndIf;	

	ReadData();
	ExecuteActionsAfterDataReadIsCompleted(); 
	
EndProcedure


Procedure CompressResultantExchangeFile()
	
	Try
		
		SourceExchangeFileName = ExchangeFileName;
		If ArchiveFile Then
			ExchangeFileName = StrReplace(ExchangeFileName, ".xml", ".zip");
		EndIf;
		
		Archiver = New ZipFileWriter(ExchangeFileName, ExchangeFileCompressionPassword, NStr("en='Data exchange file';ru='Файл обмена данными'"));
		Archiver.Add(SourceExchangeFileName);
		Archiver.Write();
		
		DeleteFiles(SourceExchangeFileName);
		
	Except
		
	EndTry;
	
EndProcedure

// Creates the file full name from directory and attachment file name.
//
// Parameters:
//  DirectoryName  - String containing path to file directory on disc.
//  FileName     - String containing attachment file name without directory name.
//
// Returns:
//   String - file full name considering the directory.
//
Function GetExchangeFileName(DirectoryName, FileName) Export

	If Not IsBlankString(FileName) Then
		Return DirectoryName + ?(Right(DirectoryName, 1) = "\", "", "\") + FileName; 
	Else
		Return DirectoryName;
	EndIf;

EndFunction

Function UnpackZIPFile(FileNameForUnpacking)
	
	DirectoryForUnpacking = TempFilesDir();
	
	UnpackedFileName = "";
	
	Try
		
		Archiver = New ZipFileReader(FileNameForUnpacking, ExchangeFileExtractionPassword);
		
		If Archiver.Items.Count() > 0 Then
			
			Archiver.Extract(Archiver.Items[0], DirectoryForUnpacking, ZIPRestoreFilePathsMode.DontRestore);
			UnpackedFileName = GetExchangeFileName(DirectoryForUnpacking, Archiver.Items[0].Name);
			
		Else
			
			UnpackedFileName = "";
			
		EndIf;
		
		Archiver.Close();
	
	Except
		
		LR = GetProtocolRecordStructure(2, ErrorDescription());
		WriteInExecutionProtocol(2, LR, True);
		
		Return "";
							
	EndTry;
	
	Return UnpackedFileName;
		
EndFunction

// Passes data string for import in the base-receiver.
//
// Parameters:
//  InformationToWriteToFile - String (XML text) - String with data.
//  ErrorStringInTargetInfobase - String - contains error description during import in the base-receiver.
// 
Procedure PassInformationAboutRecordsToReceiver(InformationToWriteToFile, ErrorStringInTargetInfobase = "") Export
	
	mDataImportDataProcessor.ExchangeFile.SetString(InformationToWriteToFile);
	
	mDataImportDataProcessor.ReadData(ErrorStringInTargetInfobase);
	
	If Not IsBlankString(ErrorStringInTargetInfobase) Then
		
		MessageString = PlaceParametersIntoString(NStr("en='Import in receiver: %1';ru='Загрузка в приемнике: %1'"), ErrorStringInTargetInfobase);
		WriteInExecutionProtocol(MessageString, Undefined, True, , , True);
		
	EndIf;
	
EndProcedure

Function RunTransferOfInformationAboutExchangeStartToReceiver(CurrentRowForWrite)
	
	If Not DirectReadInRecipientInfobase Then
		Return True;
	EndIf;
	
	CurrentRowForWrite = CurrentRowForWrite + Chars.LF + mXMLRules + Chars.LF + "</ExchangeFile>" + Chars.LF;
	
	WorkPossible = mDataImportDataProcessor.ExecuteActionsBeforeReadingData(CurrentRowForWrite);
	
	Return WorkPossible;	
	
EndFunction

Function RunTransferOfInformationOnDataTransferComplete()
	
	If Not DirectReadInRecipientInfobase Then
		Return True;
	EndIf;
	
	mDataImportDataProcessor.ExecuteActionsAfterDataReadIsCompleted();
	
EndFunction

// Writes name, type and parameter type to the exchange message file for passing to the base-receiver.
//
// Parameters:
// 
Procedure PassOneParameterToReceiver(Name, InitialParameterValue, ConversionRule = "") Export
	
	If IsBlankString(ConversionRule) Then
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		SetAttribute(ParameterNode, "Type", deValueTypeAsString(InitialParameterValue));
		
		IsNULL = False;
		Empty = deBlank(InitialParameterValue, IsNULL);
					
		If Empty Then
			
			// You should note that this value is empty.
			deWriteItem(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
	
		deWriteItem(ParameterNode, "Value", InitialParameterValue);
	
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);
		
	Else
		
		ParameterNode = CreateNode("ParameterValue");
		
		SetAttribute(ParameterNode, "Name", Name);
		
		IsNULL = False;
		Empty = deBlank(InitialParameterValue, IsNULL);
					
		If Empty Then
			
			OCRProperties = FindRule(InitialParameterValue, ConversionRule);
			ReceiverType  = OCRProperties.Receiver;
			SetAttribute(ParameterNode, "Type", ReceiverType);
			
			// You should note that this value is empty.
			deWriteItem(ParameterNode, "Empty");
								
			ParameterNode.WriteEndElement();
			
			WriteToFile(ParameterNode);
			
			Return;
								
		EndIf;
		
		DumpReferenceObjectData(InitialParameterValue, , ConversionRule, , , ParameterNode, True);
		
		ParameterNode.WriteEndElement();
		
		WriteToFile(ParameterNode);				
		
	EndIf;	
	
EndProcedure

Procedure PassAdditionalParametersToReceiver()
	
	For Each Parameter IN ParametersSettingsTable Do
		
		If Parameter.PassParameterOnExport = True Then
			
			PassOneParameterToReceiver(Parameter.Name, Parameter.Value, Parameter.ConversionRule);
					
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure PassInformationAboutTypesToReceiver()
	
	If Not IsBlankString(mTypesForTargetString) Then
		WriteToFile(mTypesForTargetString);
	EndIf;
		
EndProcedure

// Exports data according to the set modes (exchange rules).
//
// Parameters:
//  No.
//
Procedure RunExport() Export
	
	DataProcessingMode = mDataProcessingModes.Export;
	
	ExchangeProtocolInitialization();
	
	InitializeCommentsOnDumpAndDataExport();
	
	ExportPossible = True;
	CurrentNestingLevelExportByRule = 0;
	
	mDataExportCallStack = New ValueTable;
	mDataExportCallStack.Columns.Add("Ref");
	mDataExportCallStack.Indexes.Add("Ref");
	
	If mExchangeRulesReadOnImport = True Then
		
		WriteInExecutionProtocol(74);
		ExportPossible = False;	
		
	EndIf;
	
	If IsBlankString(ExchangeRulesFilename) Then
		WriteInExecutionProtocol(12);
		ExportPossible = False;
	EndIf;
	
	If Not DirectReadInRecipientInfobase Then
		
		If IsBlankString(ExchangeFileName) Then
			WriteInExecutionProtocol(10);
			ExportPossible = False;
		EndIf;
		
	Else
		
		mDataImportDataProcessor = RunConnectionToReceiverIB(); 
		
		ExportPossible = mDataImportDataProcessor <> Undefined;
		
	EndIf;
	
	// Initialize external data processor with export handlers.
	InitializationOfExternalProcessingOfEventHandlers(ExportPossible, ThisObject);
	
	If Not ExportPossible Then
		mDataImportDataProcessor = Undefined;
		Return;
	EndIf;
	
	WriteInExecutionProtocol(PlaceParametersIntoString(
		NStr("en='Export start: %1';ru='Начало выгрузки: %1'"), CurrentSessionDate()), , False, , , True);
		
	InitializeManagersAndMessages();
	
	mExportedObjectCounter = 0;
	mSnCounter 				= 0;
	ErrorFlag                  = False;

	// Exchange rules import
	If Conversion.Count() = 9 Then
		
		ImportExchangeRules();
		If ErrorFlag Then
			FinishExchangeProtocolLogging();
			mDataImportDataProcessor = Undefined;
			Return;
		EndIf;
		
	Else
		
		For Each Rule IN ConversionRulesTable Do
			Rule.Exported.Clear();
			Rule.OnlyRefsExported.Clear();
		EndDo;
		
	EndIf;

	// Assign parameters set to the dialog.
	SetParametersFromDialog();

	// Open an exchange file
	CurrentRowForWrite = OpenExportFile() + Chars.LF;
	
	If ErrorFlag Then
		ExchangeFile = Undefined;
		FinishExchangeProtocolLogging();
		mDataImportDataProcessor = Undefined;
		Return; 
	EndIf;
	
	// Determine handler interfaces.
	If HandlersDebugModeFlag Then
		
		SupplementRulesWithInterfacesOfHandlers(Conversion, ConversionRulesTable, UnloadRulesTable, FlushRulesTable);
		
	EndIf;
	
	Try
	
		// Include exchange rules to file.
		ExchangeFile.WriteLine(mXMLRules);
		
		WorkPossible = RunTransferOfInformationAboutExchangeStartToReceiver(CurrentRowForWrite);
		
		If Not WorkPossible Then
			ExchangeFile = Undefined;
			FinishExchangeProtocolLogging();
			mDataImportDataProcessor = Undefined;
			DestructorOfExternalDataProcessorOfEventHandlers();
			Return;
		EndIf;
		
		// Handler BeforeDataExport
		Cancel = False;
		Try
			
			If HandlersDebugModeFlag Then
				
				If Not IsBlankString(Conversion.BeforeDataExport) Then
					
					Execute(GetHandlerCallString(Conversion, "BeforeDataExport"));
					
				EndIf;
				
			Else
				
				Execute(Conversion.BeforeDataExport);
				
			EndIf;
			
		Except
			WriteInformationAboutErrorConversionHandlers(62, ErrorDescription(), NStr("en='BeforeDataExport (conversion)';ru='ПередВыгрузкойДанных (конвертация)'"));
			Cancel = True;
		EndTry; 
		
		If Cancel Then // Denial of the data export
			ExchangeFile = Undefined;
			FinishExchangeProtocolLogging();
			mDataImportDataProcessor = Undefined;
			DestructorOfExternalDataProcessorOfEventHandlers();
			Return;
		EndIf;
		
		If ExecuteDataExchangeInOptimizedFormat Then
			PassInformationAboutTypesToReceiver();
		EndIf;
		
		// Pass parameters to the receiver.
		PassAdditionalParametersToReceiver();
		
		EventTextAfterParameterImport = "";
		If Conversion.Property("AfterParametersImport", EventTextAfterParameterImport)
			AND Not IsBlankString(EventTextAfterParameterImport) Then
			
			WritingEvent = New XMLWriter;
			WritingEvent.SetString();
			deWriteItem(WritingEvent, "AfterParameterExportAlgorithm", EventTextAfterParameterImport);
			WriteToFile(WritingEvent);
			
		EndIf;
		
		NodeAndExportRuleMap = New Map();
		StructureForChangeRecordDeletion = New Map();
		
		ProcessDumpRules(UnloadRulesTable.Rows, NodeAndExportRuleMap);
		
		SuccessfullyExportedByExchangePlans = ProcessDumpForExchangePlans(NodeAndExportRuleMap, StructureForChangeRecordDeletion);
		
		If SuccessfullyExportedByExchangePlans Then
		
			ProcessChangeOfRegistrationForExchangeNodes(StructureForChangeRecordDeletion);
		
		EndIf;
		
		// Handler AfterDataExport
		Try
			
			If HandlersDebugModeFlag Then
				
				If Not IsBlankString(Conversion.AfterDataExport) Then
					
					Execute(GetHandlerCallString(Conversion, "AfterDataExport"));
					
				EndIf;
				
			Else
				
				Execute(Conversion.AfterDataExport);
				
			EndIf;

		Except
			WriteInformationAboutErrorConversionHandlers(63, ErrorDescription(), NStr("en='AfterDataExport (conversion)';ru='ПослеВыгрузкиДанных (конвертация)'"));
		EndTry;
		
	Except
		
		ErrorString = ErrorDescription();
		
		WriteInExecutionProtocol(PlaceParametersIntoString(
			NStr("en='An error occurred while exporting data: %1';ru='Ошибка при выгрузке данных: %1'"), ErrorString), Undefined, True, , , True);
		
		RunTransferOfInformationOnDataTransferComplete();
		
		FinishExchangeProtocolLogging();
		CloseFile();
		mDataImportDataProcessor = Undefined;
		
		Return;
		
	EndTry;
	
	If Cancel Then // Deny writing data file.
		
		RunTransferOfInformationOnDataTransferComplete();
		
		FinishExchangeProtocolLogging();
		mDataImportDataProcessor = Undefined;
		ExchangeFile = Undefined;
		
		DestructorOfExternalDataProcessorOfEventHandlers();
		
		Return;
	EndIf;
	
	// Close exchange file
	CloseFile();
	
	If ArchiveFile Then
		CompressResultantExchangeFile();
	EndIf;
	
	RunTransferOfInformationOnDataTransferComplete();
	
	WriteInExecutionProtocol(PlaceParametersIntoString(
		NStr("en='Export end: %1';ru='Окончание выгрузки: %1'"), CurrentSessionDate()), , False, , ,True);
	WriteInExecutionProtocol(PlaceParametersIntoString(
		NStr("en='Objects found: %1';ru='Выгружено объектов: %1'"), mExportedObjectCounter), , False, , , True);
	
	FinishExchangeProtocolLogging();
	
	mDataImportDataProcessor = Undefined;
	
	DestructorOfExternalDataProcessorOfEventHandlers();
	
	If ThisIsInteractiveMode Then
		MessageToUser(NStr("en='Data export is prohibited.';ru='Выгрузка данных завершена.'"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SET ATTRIBUTE VALUES AND DATA PROCESSOR MODAL VARIABLES

// Procedure of setting "ErrorCheckBox" global variable value.
//
// Parameters:
//  Value - Boolean, "ErrorCheckBox" new variable value.
//  
Procedure SetFlagOfError(Value)
	
	ErrorFlag = Value;
	
	If ErrorFlag Then
		
		DestructorOfExternalDataProcessorOfEventHandlers(DebugModeFlag);
		
	EndIf;
	
EndProcedure

// Returns current value of the data processor version.
// 
// Parameters:
//  No.
// 
// Returns:
//  Current value of the data processor version.
//
Function ObjectVersion() Export
	
	Return 218;
	
EndFunction

// Returns current value of the data processor version.
// 
// Parameters:
//  No.
// 
// Returns:
//  Current value of the data processor version.
//
Function ObjectVersioningAsString() Export
	
	Return "2.1.8";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INITIALIZE EXCHANGE RULES TABLES

Procedure AddMissingColumns(Columns, Name, Types = Undefined)
	
	If Columns.Find(Name) <> Undefined Then
		Return;
	EndIf;
	
	Columns.Add(Name, Types);	
	
EndProcedure

// Initializes table columns of object properties conversion rules.
//
// Parameters:
//  Tab            - ValuesTable. initialized table columns of properties conversion rules.
// 
Procedure PropertiesConversionRulesTableInitialization(Tab) Export

	Columns = Tab.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "IsFolder", 			deDescriptionType("Boolean"));
    AddMissingColumns(Columns, "GroupRules");

	AddMissingColumns(Columns, "SourceKind");
	AddMissingColumns(Columns, "TargetKind");
	
	AddMissingColumns(Columns, "SimplifiedPropertyExport", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExport", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "XMLNodeRequiredOnExportGroup", deDescriptionType("Boolean"));

	AddMissingColumns(Columns, "SourceType", deDescriptionType("String"));
	AddMissingColumns(Columns, "ReceiverType", deDescriptionType("String"));
	
	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Receiver");

	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "GetFromIncomingData", deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "Donotreplace", deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");

	AddMissingColumns(Columns, "BeforeProcessExport");
	AddMissingColumns(Columns, "AfterProcessExport");

	AddMissingColumns(Columns, "HasBeforeExportHandler",			deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",				deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",				deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "HasBeforeProcessExportHandler",	deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasAfterProcessExportHandler",	deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "CastToLength",	deDescriptionType("Number"));
	AddMissingColumns(Columns, "ParameterForTransferName");
	AddMissingColumns(Columns, "SearchByEqualDate",					deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "ExportGroupToFile",					deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "SearchFieldString");
	
EndProcedure

// Initializes table columns of objects conversion rules.
//
// Parameters:
//  No.
// 
Procedure ConversionRulesTableInitialization()

	Columns = ConversionRulesTable.Columns;
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "SynchronizeByID");
	AddMissingColumns(Columns, "DoNotCreateIfNotFound", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "DontExportPropertyObjectsByRefs", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "SearchBySearchFieldsIfNotFoundByID", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "OnExchangeObjectByRefSetGIUDOnly", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "UseQuickSearchOnImport", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "Generatenewnumberorcodeifnotspecified", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "TinyObjectCount", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "RefExportReferenceCount", deDescriptionType("Number"));
	AddMissingColumns(Columns, "InfobaseItemCount", deDescriptionType("Number"));
	
	AddMissingColumns(Columns, "ExportMethod");

	AddMissingColumns(Columns, "Source");
	AddMissingColumns(Columns, "Receiver");
	
	AddMissingColumns(Columns, "SourceType",  deDescriptionType("String"));

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "OnExport");
	AddMissingColumns(Columns, "AfterExport");
	AddMissingColumns(Columns, "AfterExportToFile");
	
	AddMissingColumns(Columns, "HasBeforeExportHandler",	    deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasOnExportHandler",		deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportHandler",		deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasAfterExportToFileHandler",	deDescriptionType("Boolean"));

	AddMissingColumns(Columns, "BeforeImport");
	AddMissingColumns(Columns, "OnImport");
	AddMissingColumns(Columns, "AfterImport");
	
	AddMissingColumns(Columns, "SearchFieldSequence");
	AddMissingColumns(Columns, "SearchInTabularSections");
	
	AddMissingColumns(Columns, "HasBeforeImportHandler", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasOnImportHandler",    deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "HasAfterImportHandler",  deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "HasSearchFieldSequenceHandler",  deDescriptionType("Boolean"));

	AddMissingColumns(Columns, "SearchProperties",	deDescriptionType("ValueTable"));
	AddMissingColumns(Columns, "Properties",		deDescriptionType("ValueTable"));
	
	AddMissingColumns(Columns, "Values",		deDescriptionType("Map"));

	AddMissingColumns(Columns, "Exported",							deDescriptionType("Map"));
	AddMissingColumns(Columns, "OnlyRefsExported",				deDescriptionType("Map"));
	AddMissingColumns(Columns, "ExportSourcePresentation",		deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "Donotreplace",					deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "RememberExported",       deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "AllObjectsAreExported",         deDescriptionType("Boolean"));
	
EndProcedure

// Initializes table columns of data export rules.
//
// Parameters:
//  No
// 
Procedure UnloadRulesTableInitialization()

	Columns = UnloadRulesTable.Columns;

	AddMissingColumns(Columns, "Enable",		deDescriptionType("Number"));
	AddMissingColumns(Columns, "IsFolder",		deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order");

	AddMissingColumns(Columns, "DataSelectionVariant");
	AddMissingColumns(Columns, "SelectionObject");
	
	AddMissingColumns(Columns, "ConversionRule");

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcessing");

	AddMissingColumns(Columns, "BeforeExport");
	AddMissingColumns(Columns, "AfterExport");
	
	// Columns for filter support using builder.
	AddMissingColumns(Columns, "UseFilter", deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "BuilderSettings");
	AddMissingColumns(Columns, "ObjectForQueryName");
	AddMissingColumns(Columns, "ObjectNameForRegisterQuery");
	
	AddMissingColumns(Columns, "SelectExportDataInSingleQuery", deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "ExchangeNodeRef");

EndProcedure

// Initializes table columns of data clearing rules.
//
// Parameters:
//  No.
// 
Procedure ClearRulesTableInitialization()

	Columns = FlushRulesTable.Columns;

	AddMissingColumns(Columns, "Enable",		deDescriptionType("Boolean"));
	AddMissingColumns(Columns, "IsFolder",		deDescriptionType("Boolean"));
	
	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Order",	deDescriptionType("Number"));

	AddMissingColumns(Columns, "DataSelectionVariant");
	AddMissingColumns(Columns, "SelectionObject");
	
	AddMissingColumns(Columns, "DeleteForPeriod");
	AddMissingColumns(Columns, "Directly",	deDescriptionType("Boolean"));

	AddMissingColumns(Columns, "BeforeProcess");
	AddMissingColumns(Columns, "AfterProcessing");
	AddMissingColumns(Columns, "BeforeDelete");
	
EndProcedure

// Initializes table columns of parameter settings.
//
// Parameters:
//  No.
// 
Procedure ParametersSettingTableInitialization()

	Columns = ParametersSettingsTable.Columns;

	AddMissingColumns(Columns, "Name");
	AddMissingColumns(Columns, "Description");
	AddMissingColumns(Columns, "Value");
	AddMissingColumns(Columns, "PassParameterOnExport");
	AddMissingColumns(Columns, "ConversionRule");

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INITIALIZE ATTRIBUTES AND MODULE VARIABLES

Procedure InitializeCommentsOnDumpAndDataExport()
	
	CommentDuringDataExport = "";
	CommentDuringDataImport = "";
	
EndProcedure

// Initializes MessageCode variable containing message codes matches to their descriptions.
//
// Parameters:
//  No.
// 
Procedure MessagesInitialization()

	deMessages = New Map;
	
	deMessages.Insert(2,  NStr("en='Error of exchange file unpacking. The file is locked';ru='Ошибка распаковки файла обмена. Файл заблокирован'"));
	deMessages.Insert(3,  NStr("en='The specified exchange rule file does not exist';ru='Указанный файл правил обмена не существует'"));
	deMessages.Insert(4,  NStr("en='Error while creating COM-object Msxml2.DOMDocument';ru='Ошибка при создании COM-объекта Msxml2.DOMDocument'"));
	deMessages.Insert(5,  NStr("en='File opening error';ru='Ошибка открытия файла обмена'"));
	deMessages.Insert(6,  NStr("en='Error while loading rules of exchange';ru='Ошибка при загрузке правил обмена'"));
	deMessages.Insert(7,  NStr("en='Exchange rules format error';ru='Ошибка формата правил обмена'"));
	deMessages.Insert(8,  NStr("en='File name to export data is not correct';ru='Не корректно указано имя файла для выгрузки данных'"));
	deMessages.Insert(9,  NStr("en='Exchange file format error';ru='Ошибка формата файла обмена'"));
	deMessages.Insert(10, NStr("en='File name is not specified for the data export (Name of the data file)';ru='Не указано имя файла для выгрузки данных (Имя файла данных)'"));
	deMessages.Insert(11, NStr("en='Reference to non-existing metadata object in the rules of exchange';ru='Ссылка на несуществующий объект метаданных в правилах обмена'"));
	deMessages.Insert(12, NStr("en='File name with the exchange rules (Name of the rules file) is not specified';ru='Не указано имя файла с правилами обмена (Имя файла правил)'"));
	
	deMessages.Insert(13, NStr("en='Error of receiving the object property value (by source property name)';ru='Ошибка получения значения свойства объекта (по имени свойства источника)'"));
	deMessages.Insert(14, NStr("en='error of receiving the object property value (by receiver property name)';ru='Ошибка получения значения свойства объекта (по имени свойства приемника)'"));
	
	deMessages.Insert(15, NStr("en='File name to load data not defined. (File name for loading)';ru='Не указано имя файла для загрузки данных (Имя файла для загрузки)'"));
	
	deMessages.Insert(16, NStr("en=""Error in receiving the value of the child object (in the name of property's source)"";ru='Ошибка получения значения свойства подчиненного объекта (по имени свойства источника)'"));
	deMessages.Insert(17, NStr("en=""Error in receiving the value of the child object (in the name of receiver's source)"";ru='Ошибка получения значения свойства подчиненного объекта (по имени свойства приемника)'"));
	
	deMessages.Insert(19, NStr("en='Error in the event handler BeforeObjectImport';ru='Ошибка в обработчике события ПередЗагрузкойОбъекта'"));
	deMessages.Insert(20, NStr("en='Error in the event handler OnObjectImport';ru='Ошибка в обработчике события ПриЗагрузкеОбъекта'"));
	deMessages.Insert(21, NStr("en='Error in the event handler AfterObjectImport';ru='Ошибка в обработчике события ПослеЗагрузкиОбъекта'"));
	deMessages.Insert(22, NStr("en='Error in the event handler BeforeObjectImport (conversion)';ru='Ошибка в обработчике события ПередЗагрузкойДанных (конвертация)'"));
	deMessages.Insert(23, NStr("en='Error in the event handler AfterDataImport (conversion)';ru='Ошибка в обработчике события ПослеЗагрузкиДанных (конвертация)'"));
	deMessages.Insert(24, NStr("en='An error occurred while deleting an object';ru='Ошибка при удалении объекта'"));
	deMessages.Insert(25, NStr("en='Error writing document';ru='Ошибка при записи документа'"));
	deMessages.Insert(26, NStr("en='Error writing object';ru='Ошибка записи объекта'"));
	deMessages.Insert(27, NStr("en='BeforeProcessClearingRule event handler error';ru='Ошибка в обработчике события ПередОбработкойПравилаОчистки'"));
	deMessages.Insert(28, NStr("en='Error in the event handler AfterClearingRuleProcessing';ru='Ошибка в обработчике события ПослеОбработкиПравилаОчистки'"));
	deMessages.Insert(29, NStr("en='Error in the event handler BeforeDeleteObject';ru='Ошибка в обработчике события ПередУдалениемОбъекта'"));
	
	deMessages.Insert(31, NStr("en='BeforeProcessExportRule event handler error';ru='Ошибка в обработчике события ПередОбработкойПравилаВыгрузки'"));
	deMessages.Insert(32, NStr("en='Error in the event handler AfterDumpRuleProcessing';ru='Ошибка в обработчике события ПослеОбработкиПравилаВыгрузки'"));
	deMessages.Insert(33, NStr("en='Error in the event handler BeforeObjectExport';ru='Ошибка в обработчике события ПередВыгрузкойОбъекта'"));
	deMessages.Insert(34, NStr("en='Error in the event handler AfterObjectExport';ru='Ошибка в обработчике события ПослеВыгрузкиОбъекта'"));
	
	deMessages.Insert(39, NStr("en='Error  occurred while executing the algorithm located in the exchange file';ru='Ошибка при выполнении алгоритма, содержащегося в файле обмена'"));
	
	deMessages.Insert(41, NStr("en='Error in the event handler BeforeObjectExport';ru='Ошибка в обработчике события ПередВыгрузкойОбъекта'"));
	deMessages.Insert(42, NStr("en='Error in the event handler OnObjectExport';ru='Ошибка в обработчике события ПриВыгрузкеОбъекта'"));
	deMessages.Insert(43, NStr("en='Error in the event handler AfterObjectExport';ru='Ошибка в обработчике события ПослеВыгрузкиОбъекта'"));
	
	deMessages.Insert(45, NStr("en='Object Conversion rule not found';ru='Не найдено правило конвертации объектов'"));
	
	deMessages.Insert(48, NStr("en='Error in the event handler BeforeExportProcessor properties group';ru='Ошибка в обработчике события ПередОбработкойВыгрузки группы свойств'"));
	deMessages.Insert(49, NStr("en='Error in the event handler AfterExportProcessor';ru='Ошибка в обработчике события ПослеОбработкиВыгрузки группы свойств'"));
	deMessages.Insert(50, NStr("en='Error in the event handler BeforeExport (collection object)';ru='Ошибка в обработчике события ПередВыгрузкой (объекта коллекции)'"));
	deMessages.Insert(51, NStr("en='Error in the event handler OnExport (collection object)';ru='Ошибка в обработчике события ПриВыгрузке (объекта коллекции)'"));
	deMessages.Insert(52, NStr("en='Error in the event handler AfterExport (collection object)';ru='Ошибка в обработчике события ПослеВыгрузки (объекта коллекции)'"));
	deMessages.Insert(53, NStr("en='Error in the global event handler BeforeObjectImporting (conversion)';ru='Ошибка в глобальном обработчике события ПередЗагрузкойОбъекта (конвертация)'"));
	deMessages.Insert(54, NStr("en='Error in the global handler of the AfterObjectImport (conversion) event';ru='Ошибка в глобальном обработчике события ПослеЗагрузкиОбъекта (конвертация)'"));
	deMessages.Insert(55, NStr("en='Error in the event handler BeforeExport (property)';ru='Ошибка в обработчике события ПередВыгрузкой (свойства)'"));
	deMessages.Insert(56, NStr("en='Error in the event handler OnExport (properties)';ru='Ошибка в обработчике события ПриВыгрузке (свойства)'"));
	deMessages.Insert(57, NStr("en='Error in the event handler AfterExport (properties)';ru='Ошибка в обработчике события ПослеВыгрузки (свойства)'"));
	
	deMessages.Insert(62, NStr("en='Error in the event handler BeforeDataExport (properties)';ru='Ошибка в обработчике события ПередВыгрузкойДанных (конвертация)'"));
	deMessages.Insert(63, NStr("en='Error in the event handler AfterDataExport (conversion)';ru='Ошибка в обработчике события ПослеВыгрузкиДанных (конвертация)'"));
	deMessages.Insert(64, NStr("en='Error in the global event handler BeforeObjectConversion (conversion)';ru='Ошибка в глобальном обработчике события ПередКонвертациейОбъекта (конвертация)'"));
	deMessages.Insert(65, NStr("en='Error in the global event handler BeforeObjectExport (conversion)';ru='Ошибка в глобальном обработчике события ПередВыгрузкойОбъекта (конвертация)'"));
	deMessages.Insert(66, NStr("en='Error of receiving the collection of subordinate objects from incoming data';ru='Ошибка получения коллекции подчиненных объектов из входящих данных'"));
	deMessages.Insert(67, NStr("en='Error retrieving subordinate object properties from incoming data';ru='Ошибка получения свойства подчиненного объекта из входящих данных'"));
	deMessages.Insert(68, NStr("en=""Error of receiving object's property from incoming data"";ru='Ошибка получения свойства объекта из входящих данных'"));
	
	deMessages.Insert(69, NStr("en='Error in the global event handler AfterObjectExport (conversion)';ru='Ошибка в глобальном обработчике события ПослеВыгрузкиОбъекта (конвертация)'"));
	
	deMessages.Insert(71, NStr("en='The map of the Source value is not found';ru='Не найдено соответствие для значения Источника'"));
	
	deMessages.Insert(72, NStr("en='Error exporting data for exchange plan node';ru='Ошибка при выгрузке данных для узла плана обмена'"));
	
	deMessages.Insert(73, NStr("en='Error in the event handler SearchFieldsSequence';ru='Ошибка в обработчике события ПоследовательностьПолейПоиска'"));
	
	deMessages.Insert(74, NStr("en='Exchange rules for data export must be reread';ru='Необходимо перезагрузить правила обмена для выгрузки данных'"));
	
	deMessages.Insert(75, NStr("en='Error occurred while executing the algorithm after loading the parameters values';ru='Ошибка при выполнении алгоритма после загрузки значений параметров'"));
	
	deMessages.Insert(76, NStr("en='Error in the event handler AfterObjectExportToFile';ru='Ошибка в обработчике события ПослеВыгрузкиОбъектаВФайл'"));
	
	deMessages.Insert(77, NStr("en='The external data processor file with pluggable event handler procedures is not specified';ru='Не указан файл внешней обработки с подключаемыми процедурами обработчиков событий'"));
	
	deMessages.Insert(78, NStr("en='Error creating external data processor from file with event handler procedures';ru='Ошибка создания внешней обработки из файла с процедурами обработчиков событий'"));
	
	deMessages.Insert(79, NStr("en='Algorithms code can not be integrated to the handler because of the found recursive algorithms call. 
		|If in the process of debugging there is no need to debug algorithms
		|code, specify ""do not debug algorithms"" mode If it is required to debug algorithms with a recursive
		|call, then specify ""debug algorithms as procedures"" mode and repeat import.';ru='Код алгоритмов не может быть интегрирован в обработчик из-за обнаруженного рекурсивного вызова алгоритмов. 
		|Если в процессе отладки нет необходимости отлаживать код
		|алгоритмов, то укажите режим ""не отлаживать алгоритмы"" Если необходимо выполнять отладку алгоритмов с рекурсивным
		|вызовом, то укажите режим ""алгоритмы отлаживать как процедуры"" и повторите выгрузку.'"));
	
	deMessages.Insert(80, NStr("en='You must have the full rights to execute the data exchange';ru='Обмен данными можно проводить только под полными правами'"));
	
	deMessages.Insert(1000, NStr("en='Error creating temporary data export file';ru='Ошибка при создании временного файла выгрузки данных'"));

EndProcedure

Procedure SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, TypeName, Manager, TypeNamePrefix, SearchByPredefinedPossible = False)
	
	Name              = MDObject.Name;
	RefTypeAsString = TypeNamePrefix + "." + Name;
	SearchString     = "SELECT Ref FROM " + TypeName + "." + Name + " WHERE ";
	ReferenceType        = Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchString,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, SearchString, SearchByPredefinedPossible);
	Managers.Insert(ReferenceType, Structure);
	
	
	StructureForExchangePlan = New Structure("Name,ReferenceType,IsReferenceType,ThisIsRegister", Name, ReferenceType, True, False);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
EndProcedure

Procedure SupplementManagersArrayWithRegisterType(Managers, MDObject, TypeName, Manager, TypeNamePrefixRecord, SelectionTypeNamePrefix)
	
	Periodical = Undefined;
	
	Name					= MDObject.Name;
	RefTypeAsString	= TypeNamePrefixRecord + "." + Name;
	ReferenceType			= Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, False);
	
	If TypeName = "InformationRegister" Then
		
		Periodical = (MDObject.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical);
		SubordinatedToRecorder = (MDObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);
		
	EndIf;	
	
	Managers.Insert(ReferenceType, Structure);
		

	StructureForExchangePlan = New Structure("Name,ReferenceType,IsReferenceType,ThisIsRegister", Name, ReferenceType, False, True);
	ManagersForExchangePlans.Insert(MDObject, StructureForExchangePlan);
	
	
	RefTypeAsString	= SelectionTypeNamePrefix + "." + Name;
	ReferenceType			= Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, False);
	
	If Periodical <> Undefined Then
		
		Structure.Insert("Periodical", Periodical);
		Structure.Insert("SubordinatedToRecorder", SubordinatedToRecorder);	
		
	EndIf;
	
	Managers.Insert(ReferenceType, Structure);	
		
EndProcedure

// Initializes the Managers variable containing match of object types to their properties.
//
// Parameters:
//  No.
// 
Procedure ManagersInitialization()

	Managers = New Map;
	
	ManagersForExchangePlans = New Map;
    	
	// REFS
	
	For Each MDObject IN Metadata.Catalogs Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "Catalog", Catalogs[MDObject.Name], "CatalogRef", True);
					
	EndDo;

	For Each MDObject IN Metadata.Documents Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "Document", Documents[MDObject.Name], "DocumentRef");
				
	EndDo;

	For Each MDObject IN Metadata.ChartsOfCharacteristicTypes Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCharacteristicTypes", ChartsOfCharacteristicTypes[MDObject.Name], "ChartOfCharacteristicTypesRef", True);
				
	EndDo;
	
	For Each MDObject IN Metadata.ChartsOfAccounts Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ChartOfAccounts", ChartsOfAccounts[MDObject.Name], "ChartOfAccountsRef", True);
						
	EndDo;
	
	For Each MDObject IN Metadata.ChartsOfCalculationTypes Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ChartOfCalculationTypes", ChartsOfCalculationTypes[MDObject.Name], "ChartOfCalculationTypesRef", True);
				
	EndDo;
	
	For Each MDObject IN Metadata.ExchangePlans Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "ExchangePlan", ExchangePlans[MDObject.Name], "ExchangePlanRef");
				
	EndDo;
	
	For Each MDObject IN Metadata.Tasks Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "Task", Tasks[MDObject.Name], "TaskRef");
				
	EndDo;
	
	For Each MDObject IN Metadata.BusinessProcesses Do
		
		SupplementManagersArrayWithRefType(Managers, ManagersForExchangePlans, MDObject, "BusinessProcess", BusinessProcesses[MDObject.Name], "BusinessProcessRef");
		
		TypeName = "BusinessProcessRoutePoint";
		// ref to the route points
		Name              = MDObject.Name;
		Manager         = BusinessProcesses[Name].RoutePoints;
		SearchString     = "";
		RefTypeAsString = "BusinessProcessRoutePointRef." + Name;
		ReferenceType        = Type(RefTypeAsString);
		Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible,SearchString", Name, 
			TypeName, RefTypeAsString, Manager, MDObject, , Undefined, False, SearchString);		
		Managers.Insert(ReferenceType, Structure);
				
	EndDo;
	
	// REGISTERS

	For Each MDObject IN Metadata.InformationRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "InformationRegister", InformationRegisters[MDObject.Name], "InformationRegisterRecord", "InformationRegisterSelection");
						
	EndDo;

	For Each MDObject IN Metadata.AccountingRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "AccountingRegister", AccountingRegisters[MDObject.Name], "AccountingRegisterRecord", "AccountingRegisterSelection");
				
	EndDo;
	
	For Each MDObject IN Metadata.AccumulationRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "AccumulationRegister", AccumulationRegisters[MDObject.Name], "AccumulationRegisterRecord", "AccumulationRegisterSelection");
						
	EndDo;
	
	For Each MDObject IN Metadata.CalculationRegisters Do
		
		SupplementManagersArrayWithRegisterType(Managers, MDObject, "CalculationRegister", CalculationRegisters[MDObject.Name], "CalculationRegisterRecord", "CalculationRegisterSelection");
						
	EndDo;
	
	TypeName = "Enum";
	
	For Each MDObject IN Metadata.Enums Do
		
		Name              = MDObject.Name;
		Manager         = Enums[Name];
		RefTypeAsString = "EnumRef." + Name;
		ReferenceType        = Type(RefTypeAsString);
		Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,OCR,EmptyRef,SearchByPredefinedPossible", Name, TypeName, RefTypeAsString, Manager, MDObject, , Enums[Name].EmptyRef(), False);
		Managers.Insert(ReferenceType, Structure);
		
	EndDo;	
	
	// Constants
	TypeName             = "Constants";
	MDObject            = Metadata.Constants;
	Name					= "Constants";
	Manager			= Constants;
	RefTypeAsString	= "ConstantsSet";
	ReferenceType			= Type(RefTypeAsString);
	Structure = New Structure("Name,TypeName,RefTypeAsString,Manager,MDObject,SearchByPredefinedPossible,OCR", Name, TypeName, RefTypeAsString, Manager, MDObject, False);
	Managers.Insert(ReferenceType, Structure);
	
EndProcedure

// Initializes object managers and all messages of the data exchange protocol.
//
// Parameters:
//  No.
// 
Procedure InitializeManagersAndMessages() Export
	
	If Managers = Undefined Then
		ManagersInitialization();
	EndIf; 

	If deMessages = Undefined Then
		MessagesInitialization();
	EndIf;
	
EndProcedure

Procedure CreateConversionStructure()
	
	Conversion  = New Structure("BeforeDataExport, AfterDataExport, BeforeObjectExport, AfterObjectExport, BeforeObjectConversion, BeforeObjectImport, AftertObjectImport, BeforeDataImport, AfterDataImport");
	
EndProcedure

// Initializes data processor attributes and module variables.
//
// Parameters:
//  No.
// 
Procedure AttributesAndModuleVariablesInitialization()

	CountProcessedObjectsForRefreshStatus = 100;
	
	RememberImportedObjects     = True;
	ImportedObjectToStoreCount = 5000;
	
	ParametersInitialized        = False;
	
	KeepAdditionalWriteControlToXML = False;
	DirectReadInRecipientInfobase = False;
	DontOutputNoInformationMessagesToUser = False;
	
	Managers    = Undefined;
	deMessages  = Undefined;
	
	ErrorFlag   = False;
	
	CreateConversionStructure();
	
	Rules      = New Structure;
	Algorithms    = New Structure;
	AdditionalInformationProcessors = New Structure;
	Queries      = New Structure;

	Parameters    = New Structure;
	EventsAfterParameterImport = New Structure;
	
	AdditionalInformationProcessorParameters = New Structure;
	
	// Types
	deStringType                  = Type("String");
	deBooleanType                  = Type("Boolean");
	deNumberType                   = Type("Number");
	deDateType                    = Type("Date");
	deValueStorageType       = Type("ValueStorage");
	deUUIDType = Type("UUID");
	deBinaryDataType          = Type("BinaryData");
	deAccumulationRecordTypeType   = Type("AccumulationRecordType");
	deObjectDeletionType         = Type("ObjectDeletion");
	deAccountTypeType			     = Type("AccountType");
	deTypeType                     = Type("Type");
	deMapType            = Type("Map");

	EmptyDateValue		   = Date('00010101');
	
	mXMLRules  = Undefined;
	
	// Xml node types
	
	odNodeTypeXML_EndElement  = XMLNodeType.EndElement;
	odNodeTypeXML_StartElement = XMLNodeType.StartElement;
	odNodeTypeXML_Text          = XMLNodeType.Text;


	mExchangeRuleTemplateList  = New ValueList;

	For Each Template IN ThisObject.Metadata().Templates Do
		mExchangeRuleTemplateList.Add(Template.Synonym);
	EndDo; 
	    	
	mDataLogFile = Undefined;
	
	InfobaseTypeForConnection = True;
	InfobaseConnectionWindowsAuthentication = False;
	InfobaseForConnectionPlatformVersion = "V8";
	OpenExchangeProtocolAfterOperationsComplete = False;
	ImportDataInExchangeMode = True;
	WriteToInformationBaseChangedObjectsOnly = True;
	WriteRegistersViaRecordSets = True;
	OptimizedObjectWriting = True;
	ExportAllowedOnly = True;
	ImportObjectsByRefWithoutDeletionMark = True;	
	UseFilterByDateForAllObjects = True;
	
	mEmptyTypeValueMap = New Map;
	mTypeDescriptionMap = New Map;
	
	mExchangeRulesReadOnImport = False;

	EventHandlersReadFromFileOfExchangeRules = True;
	
	mDataProcessingModes = New Structure;
	mDataProcessingModes.Insert("Export",                   0);
	mDataProcessingModes.Insert("Import",                   1);
	mDataProcessingModes.Insert("ExchangeRuleImport",       2);
	mDataProcessingModes.Insert("EventHandlerExport", 3);
	
	DataProcessingMode = mDataProcessingModes.Export;
	
	mAlgorithmDebugModes = New Structure;
	mAlgorithmDebugModes.Insert("DontUse",   0);
	mAlgorithmDebugModes.Insert("ProceduralCall", 1);
	mAlgorithmDebugModes.Insert("CodeIntegration",   2);
	
	AlgorithmsDebugMode = mAlgorithmDebugModes.DontUse;
	
EndProcedure

Function DefineSufficiencyOfParametersForConnectionToInformationBase(ConnectionStructure, ConnectionString = "", ErrorMessageString = "")
	
	ErrorsExist = False;
	
	If ConnectionStructure.FileModeVersion  Then
		
		If IsBlankString(ConnectionStructure.InfobaseDirectory) Then
			
			ErrorMessageString = NStr("en='Information base-receiver directory is not specified';ru='Не задан каталог информационной базы-приемника'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		ConnectionString = "File=""" + ConnectionStructure.InfobaseDirectory + """";
	Else
		
		If IsBlankString(ConnectionStructure.ServerName) Then
			
			ErrorMessageString = NStr("en='1C:Enterprise server name of infobase-receiver is not specified';ru='Не задано имя сервера 1С:Предприятия информационной базы-приемника'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;
		
		If IsBlankString(ConnectionStructure.InfobaseNameAtServer) Then
			
			ErrorMessageString = NStr("en='Information base-receiver name is not specified on the 1C:Enterprise server';ru='Не задано имя информационной базы-приемника на сервере 1С:Предприятия'");
			
			MessageToUser(ErrorMessageString);
			
			ErrorsExist = True;
			
		EndIf;		
		
		ConnectionString = "Srvr = """ + ConnectionStructure.ServerName + """; Ref = """ + ConnectionStructure.InfobaseNameAtServer + """";		
		
	EndIf;
	
	Return Not ErrorsExist;	
	
EndFunction

Function ConnectToInformationBase(ConnectionStructure, ErrorMessageString = "")
	
	Var ConnectionString;
	
	EnoughParameters = DefineSufficiencyOfParametersForConnectionToInformationBase(ConnectionStructure, ConnectionString, ErrorMessageString);
	
	If Not EnoughParameters Then
		Return Undefined;
	EndIf;
	
	If Not ConnectionStructure.OSAuthentication Then
		If Not IsBlankString(ConnectionStructure.User) Then
			ConnectionString = ConnectionString + ";Usr = """ + ConnectionStructure.User + """";
		EndIf;
		If Not IsBlankString(ConnectionStructure.Password) Then
			ConnectionString = ConnectionString + ";Pwd = """ + ConnectionStructure.Password + """";
		EndIf;
	EndIf;
	
	// "V82" or "V83"
	ConnectionObject = ConnectionStructure.PlatformVersion;
	
	ConnectionString = ConnectionString + ";";
	
	Try
		
		ConnectionObject = ConnectionObject +".COMConnector";
		CurrentCOMConnection = New COMObject(ConnectionObject);
		CurCOMObject = CurrentCOMConnection.Connect(ConnectionString);
		
	Except
		
		ErrorMessageString = NStr("en='The following error occurred while trying to
		|connect to COM-server: %1';ru='При попытке соединения с COM-сервером
		|произошла следующая ошибка: %1'");
		ErrorMessageString = PlaceParametersIntoString(ErrorMessageString, ErrorDescription());
		
		MessageToUser(ErrorMessageString);
		
		Return Undefined;
		
	EndTry;
	
	Return CurCOMObject;
	
EndFunction

// Function returns string part after the last met character in the string.
Function GetStringSplitBySymbol(Val SourceLine, Val SearchChar)
	
	CharPosition = StrLen(SourceLine);
	While CharPosition >= 1 Do
		
		If Mid(SourceLine, CharPosition, 1) = SearchChar Then
						
			Return Mid(SourceLine, CharPosition + 1); 
			
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;

	Return "";
  	
EndFunction

// Selects an extension from the attachment file name (characters set after the last point).
//
// Parameters:
//  FileName     - String containing attachment file name, it does not matter with or without directory name.
//
// Returns:
//   String - file extension.
//
Function GetFileNameExtension(Val FileName) Export
	
	Extension = GetStringSplitBySymbol(FileName, ".");
	Return Extension;
	
EndFunction

Function GetProtocolNameForSecondInformationBaseOfCOMConnection()
	
	If Not IsBlankString(ExchangeProtocolFileNameImporting) Then
			
		Return ExchangeProtocolFileNameImporting;	
		
	ElsIf Not IsBlankString(ExchangeProtocolFileName) Then
		
		LogFileExtension = GetFileNameExtension(ExchangeProtocolFileName);
		
		If Not IsBlankString(LogFileExtension) Then
							
			ExportLogFileName = StrReplace(ExchangeProtocolFileName, "." + LogFileExtension, "");
			
		EndIf;
		
		ExportLogFileName = ExportLogFileName + "_Import";
		
		If Not IsBlankString(LogFileExtension) Then
			
			ExportLogFileName = ExportLogFileName + "." + LogFileExtension;	
			
		EndIf;
		
		Return ExportLogFileName;
		
	EndIf;
	
	Return "";
	
EndFunction

// Connects to the base-receiver by the specified parameters.
// Returns the UniversalXMLDataExchange initialized
// data processor of a base-receiver that will be used for data import to the base-receiver.
// 
// Parameters:
//  No.
// 
//  Returns:
//  DataProcessorObject - UniversalXMLDataExchange - base-receiver data processor for data import to the base-receiver.
//
Function RunConnectionToReceiverIB() Export
	
	ConnectionResult = Undefined;
	
	ConnectionStructure = New Structure();
	ConnectionStructure.Insert("FileModeVersion", InfobaseTypeForConnection);
	ConnectionStructure.Insert("OSAuthentication", InfobaseConnectionWindowsAuthentication);
	ConnectionStructure.Insert("InfobaseDirectory", InfobaseForConnectionDirectory);
	ConnectionStructure.Insert("ServerName", InfobaseForConnectionServerName);
	ConnectionStructure.Insert("InfobaseNameAtServer", InfobaseNameOnServerForConnection);
	ConnectionStructure.Insert("User", InfobaseForConnectionUser);
	ConnectionStructure.Insert("Password", InfobaseForConnectionPassword);
	ConnectionStructure.Insert("PlatformVersion", InfobaseForConnectionPlatformVersion);
	
	ConnectionObject = ConnectToInformationBase(ConnectionStructure);
	
	If ConnectionObject = Undefined Then
		Return Undefined;
	EndIf;
	
	Try
		ConnectionResult = ConnectionObject.DataProcessors.UniversalXMLDataExchange.Create();
	Except
		
		Text = NStr("en='An error occurred while trying to create the UniversalXMLDataExchange data processor: %1';ru='При попытке создания обработки УниверсальныйОбменДаннымиXML произошла ошибка: %1'");
		Text = PlaceParametersIntoString(Text, BriefErrorDescription(ErrorInfo()));
		MessageToUser(Text);
		ConnectionResult = Undefined;
	EndTry;
	
	If ConnectionResult <> Undefined Then
		
		ConnectionResult.UseTransactions = UseTransactions;	
		ConnectionResult.ObjectsCountForTransactions = ObjectsCountForTransactions;
		
		ConnectionResult.DebugModeFlag = DebugModeFlag;
		
		ConnectionResult.ExchangeProtocolFileName = GetProtocolNameForSecondInformationBaseOfCOMConnection();
								
		ConnectionResult.AppendDataToExchangeProtocol = AppendDataToExchangeProtocol;
		ConnectionResult.OutputInInformationMessagesToProtocol = OutputInInformationMessagesToProtocol;
		
		ConnectionResult.ExchangeMode = "Import";
		
	EndIf;
	
	Return ConnectionResult;
	
EndFunction

// Deletes objects of the specified type according to
// the data clearing rules (physical deletion or mark for deletion).
//
// Parameters:
//  TypeNameToRemove - String - type name in the row presentation.
// 
Procedure DeleteTypeObjects(TypeNameToRemove) Export
	
	DataToDeleteType = Type(TypeNameToRemove);
	
	Manager = Managers[DataToDeleteType];
	TypeName  = Manager.TypeName;
	Name      = Manager.Name;	
	Properties	= Managers[DataToDeleteType];
	
	Rule = New Structure("Name,Directly,BeforeDelete", "ObjectDeletion", True, "");
					
	Selection = GetSelectionForDataDumpClear(Properties, TypeName, True, True, False);
	
	While Selection.Next() Do
		
		If TypeName =  "InformationRegister" Then
			
			RecordManager = Properties.Manager.CreateRecordManager(); 
			FillPropertyValues(RecordManager, Selection);
								
			DeletionOfSelectionObject(RecordManager, Rule, Properties, Undefined);
				
		Else
				
			DeletionOfSelectionObject(Selection.Ref.GetObject(), Rule, Properties, Undefined);
				
		EndIf;
			
	EndDo;	
	
EndProcedure

Procedure SupplementSystemTablesWithColumns()
	
	ConversionRulesTableInitialization();
	UnloadRulesTableInitialization();
	ClearRulesTableInitialization();
	ParametersSettingTableInitialization();	
	
EndProcedure

// Initializes external data processor with the event handlers debugging module.
//
// Parameters:
//  WorkPossible - Boolean - check box of a successful external data processor initialization.
//  OwnerObject - DataProcessorObject - object that will be an
// initialized external data processor owner.
//  
Procedure InitializationOfExternalProcessingOfEventHandlers(WorkPossible, OwnerObject) Export
	
	If Not WorkPossible Then
		Return;
	EndIf; 
	
	If HandlersDebugModeFlag AND IsBlankString(EventHandlersExternalDataProcessorFileName) Then
		
		WriteInExecutionProtocol(77); 
		WorkPossible = False;
		
	ElsIf HandlersDebugModeFlag Then
		
		Try
			
			If IsExternalDataProcessor() Then
				
				EventHandlerExternalDataProcessor = ExternalDataProcessors.Create(EventHandlersExternalDataProcessorFileName, False);
				
			Else
				
				EventHandlerExternalDataProcessor = DataProcessors[EventHandlersExternalDataProcessorFileName].Create();
				
			EndIf;
			
			EventHandlerExternalDataProcessor.Assistant(OwnerObject);
			
		Except
			
			DestructorOfExternalDataProcessorOfEventHandlers();
			
			MessageToUser(BriefErrorDescription(ErrorInfo()));
			WriteInExecutionProtocol(78);
			
			WorkPossible               = False;
			HandlersDebugModeFlag = False;
			
		EndTry;
		
	EndIf;
	
	If WorkPossible Then
		
		CommonProcedureFunctions = ThisObject;
		
	EndIf; 
	
EndProcedure

// External data processor destructor.
//
// Parameters:
//  No.
//  
// External data processor destructor.
//
// Parameters:
//  No.
//  
Procedure DestructorOfExternalDataProcessorOfEventHandlers(EnabledDebugMode = False) Export
	
	If Not EnabledDebugMode Then
		
		If EventHandlerExternalDataProcessor <> Undefined Then
			
			Try
				
				EventHandlerExternalDataProcessor.Destructor();
				
			Except
				MessageToUser(BriefErrorDescription(ErrorInfo()));
			EndTry; 
			
		EndIf; 
		
		EventHandlerExternalDataProcessor = Undefined;
		CommonProcedureFunctions               = Undefined;
		
	EndIf;
	
EndProcedure

// Deletes temporary files with the specified name.
//
// Parameters:
//  TempFileName - String - full name of the file being deleted. It is cleared after executing the procedure.
//  
Procedure DeleteTemporaryFiles(TempFileName) Export
	
	If Not IsBlankString(TempFileName) Then
		
		Try
			
			DeleteFiles(TempFileName);
			
			TempFileName = "";
			
		Except
		EndTry; 
		
	EndIf; 
	
EndProcedure  

Function GetNewUniqueNameOfTemporaryFile(Prefix, Extension, OldTempFileName)
	
	// Delete the previous temporary file.
	DeleteTemporaryFiles(OldTempFileName);
	
	UUID = New UUID();
	
	Prefix    = ?(IsBlankString(Prefix), "", Prefix + "_");
	
	Extension = ?(IsBlankString(Extension), "", "." + Extension);
	
	Return TempFilesDir() + Prefix + UUID + Extension;
EndFunction 

Procedure InitializationOfStructureOfHandlerNames()
	
	// Conversion handlers.
	ConversionHandlerNames = New Structure;
	ConversionHandlerNames.Insert("BeforeDataExport");
	ConversionHandlerNames.Insert("AfterDataExport");
	ConversionHandlerNames.Insert("BeforeObjectExport");
	ConversionHandlerNames.Insert("AfterObjectExport");
	ConversionHandlerNames.Insert("BeforeObjectConversion");
	ConversionHandlerNames.Insert("BeforeSendDeletionInfo");
	ConversionHandlerNames.Insert("BeforeGetChangedObjects");
	
	ConversionHandlerNames.Insert("BeforeObjectImport");
	ConversionHandlerNames.Insert("AftertObjectImport");
	ConversionHandlerNames.Insert("BeforeDataImport");
	ConversionHandlerNames.Insert("AfterDataImport");
	ConversionHandlerNames.Insert("OnGetDeletionInfo");
	ConversionHandlerNames.Insert("AfterGetExchangeNodeDetails");
	
	ConversionHandlerNames.Insert("AfterExchangeRuleImport");
	ConversionHandlerNames.Insert("AfterParametersImport");
	
	// OCR handlers.
	OCRHandlerNames = New Structure;
	OCRHandlerNames.Insert("BeforeExport");
	OCRHandlerNames.Insert("OnExport");
	OCRHandlerNames.Insert("AfterExport");
	OCRHandlerNames.Insert("AfterExportToFile");
	
	OCRHandlerNames.Insert("BeforeImport");
	OCRHandlerNames.Insert("OnImport");
	OCRHandlerNames.Insert("AfterImport");
	
	OCRHandlerNames.Insert("SearchFieldSequence");
	
	// PCR handlers.
	PCRHandlerNames = New Structure;
	PCRHandlerNames.Insert("BeforeExport");
	PCRHandlerNames.Insert("OnExport");
	PCRHandlerNames.Insert("AfterExport");

	// PGCR handlers.
	PGCRHandlerNames = New Structure;
	PGCRHandlerNames.Insert("BeforeExport");
	PGCRHandlerNames.Insert("OnExport");
	PGCRHandlerNames.Insert("AfterExport");
	
	PGCRHandlerNames.Insert("BeforeProcessExport");
	PGCRHandlerNames.Insert("AfterProcessExport");
	
	// DDR handlers.
	DDRHandlerNames = New Structure;
	DDRHandlerNames.Insert("BeforeProcess");
	DDRHandlerNames.Insert("AfterProcessing");
	DDRHandlerNames.Insert("BeforeExport");
	DDRHandlerNames.Insert("AfterExport");
	
	// DCR handlers.
	DCRHandlerNames = New Structure;
	DCRHandlerNames.Insert("BeforeProcess");
	DCRHandlerNames.Insert("AfterProcessing");
	DCRHandlerNames.Insert("BeforeDelete");
	
	// Global structure with handler names.
	HandlerNames = New Structure;
	HandlerNames.Insert("Conversion", ConversionHandlerNames); 
	HandlerNames.Insert("OCR",         OCRHandlerNames); 
	HandlerNames.Insert("PCR",         PCRHandlerNames); 
	HandlerNames.Insert("PGCR",        PGCRHandlerNames); 
	HandlerNames.Insert("DDR",         DDRHandlerNames); 
	HandlerNames.Insert("DCR",         DCRHandlerNames); 
	
EndProcedure  

// Outputs message to a user.
//
// Parameters:
// MessageToUserText - String - Output message text.
//
Procedure MessageToUser(MessageToUserText) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Message();
	
EndProcedure

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
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	LookupString = StrReplace(LookupString, "%1", Parameter1);
	LookupString = StrReplace(LookupString, "%2", Parameter2);
	LookupString = StrReplace(LookupString, "%3", Parameter3);
	
	Return LookupString;
	
EndFunction

Function IsExternalDataProcessor()
	
	Return ?(Find(EventHandlersExternalDataProcessorFileName, ".") <> 0, True, False);
	
EndFunction

Function PredefinedName(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	| PredefinedDataName AS PredefinedDataName
	|FROM
	|	" + Ref.Metadata().FullName() + " AS
	|SpecifiedTableAlias
	|WHERE SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.PredefinedDataName;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// MAIN PROGRAM OPERATORS

AttributesAndModuleVariablesInitialization();
SupplementSystemTablesWithColumns();
InitializationOfStructureOfHandlerNames();



#EndIf
