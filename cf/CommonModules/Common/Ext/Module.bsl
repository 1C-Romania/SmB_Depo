
////////////////////////////////////////////////////////////////////////////////


Function DetectIsThisInfobaseIsLocal(ConnectionWithDatabaseString = "") Export
			
	ConnectionWithDatabaseString = ?(IsBlankString(ConnectionWithDatabaseString), InfoBaseConnectionString(), ConnectionWithDatabaseString);
	
	SearchPosition = Find(Upper(ConnectionWithDatabaseString), "FILE=");
	
	Return SearchPosition = 1;	
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH NUMBERS 

// Reduces String value (almost number value) to number value, if possible
// E.g. " 100 szt." -> "100", "1.54zł." -> "1,54"
// Works by trimming blank spaces and non-numeric characters from both sides
Function GetNumberReducedFromString(Val StringNumber) Export 

	// Remove all blank spaces and replace dots with commas
	StringNumber = StrReplace(StrReplace(StringNumber, " ", ""), ".", ",");
		
	While True Do
		
		If StringNumber = "" Then 
			Break;
		EndIf;
		
		// Check if the most right character of the String is numeric
		Try                                                                        			
			Digit = Number(Right(StringNumber, 1));
			// If the most right character of the String is numeric, then quit loop
			Break;                                                                 			
		Except
			StringNumber = Left(StringNumber, StrLen(StringNumber)-1);
		EndTry;
		
	EndDo;
	
	While True Do
		
		If StringNumber = "" Then 
			Break;
		EndIf;
		
		// Check if the most left character of the String is numeric
		Try                                                                        			
			Digit = Number(Left(StringNumber, 1));
			// If the most left character of the String is numeric, then quit loop
			Break;                                                                 			
		Except
			StringNumber = Right(StringNumber, StrLen(StringNumber)-1);
		EndTry;
		
	EndDo;
	
	Return StringNumber;		
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH CURRENCIES 

// Finding first tabular part row, that agree with filter.
//
// Returning values:
//  Tabular part row - finded row,
//  Undefined        - if the row was not founded.
//
Function FindTabularPartRow(TabularPart, RowFilterStructure) Export 
	
	RowsArray = TabularPart.FindRows(RowFilterStructure);
	
	If RowsArray.Count() = 0 Then
		Return Undefined;                  
	Else
		Return RowsArray[0];
	EndIf;
	
EndFunction // FindTabularPartRow()

Function GetDocumentCaption(DocumentRef, DocumentSynonym = "") Export 
	Result = "";
	If DocumentRef<>Undefined Then
		DocumentSynonym = ?(IsBlankString(DocumentSynonym), DocumentRef.Metadata().Synonym, DocumentSynonym);
		NumberAndDate = " #" + DocumentRef.Number + NStr("en=' date ';pl=' data '") + Format(DocumentRef.Date, "DLF=D");
		Result = DocumentSynonym + NumberAndDate;
	EndIf;
	Return Result;

EndFunction // GetDocumentCaption()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CHECKING EXISTENCE AND FILLING OF ATTRIBUTES
Function IsDocumentTabularPart(TabularPartName, DocumentMetadata) Export 

	Return Not (DocumentMetadata.TabularSections.Find(TabularPartName) = Undefined);

EndFunction // IsDocumentTabularPart()

Function IsDocumentTabularPartAttribute(AttributeName, DocumentMetadata, TabularPartName) Export 
	
	TabularPart = DocumentMetadata.TabularSections.Find(TabularPartName);
	
	If TabularPart = Undefined Then
		Return False;
	Else
		Return Not (TabularPart.Attributes.Find(AttributeName) = Undefined);
	EndIf;

EndFunction // IsDocumentTabularPartAttribute()

Function GetEnumValueByName(EnumObject,EnumName) Export
	
	If EnumName = "" Then
		
		Return EnumObject.EmptyRef();
		

	Else
		Try
		
			GotEnum = EnumObject[EnumName];
		
		Except
			
			Return EnumObject.EmptyRef();
			
		EndTry; 
		
		Return GotEnum;
		
	EndIf;
	
EndFunction // GetEnumValueByName()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH TYPES

Function GetStringTypeDescription(StringLenth) Export 
	
	Return GetTypeDescription("String", StringLenth);
	
EndFunction // GetStringTypeDescription()

Function GetNumberTypeDescription(Digits, FractionDigits = 0) Export 
	
	Return GetTypeDescription("Number", Digits, FractionDigits);
	
EndFunction // GetNumberTypeDescription()

Function GetDateTypeDescription(SetDateFractions = Undefined) Export 
	
	Return GetTypeDescription("Date", , , SetDateFractions);
	
EndFunction // GetDateTypeDescription()

Function GetBooleanTypeDescription() Export 
	
	Return GetTypeDescription("Boolean");
	
EndFunction // GetBooleanTypeDescription()

Function GetTypeDescription(TypeName = "", Digits = 0, FractionDigits = 0, SetDateFractions = Undefined) Export 
	
	Var TypeDescription;
	
	If TypeOf(TypeName) = Type("String") Then
		
		Array = New Array;
		
		If Not IsBlankString(TypeName) Then
			Array.Add(Type(TypeName));
		EndIf;
		
		If TypeName = "Number" Then
			
			Qualifier = New NumberQualifiers(Digits, FractionDigits);
			TypeDescription = New TypeDescription(Array, Qualifier);
			
		ElsIf TypeName = "String" Then
			
			If FractionDigits = 0 Then
				Qualifier = New StringQualifiers(Digits);
			Else
				Qualifier = New StringQualifiers(Digits, FractionDigits);
			EndIf;
			
			TypeDescription = New TypeDescription(Array, , Qualifier);
			
		ElsIf TypeName = "Date" Then
			
			If SetDateFractions = Undefined Then
				SetDateFractions = DateFractions.Date;
			EndIf;
			
			Qualifier = New DateQualifiers(SetDateFractions);
			TypeDescription = New TypeDescription(Array, , , Qualifier);
			
		Else
			
			TypeDescription = New TypeDescription(Array);
			
		EndIf;
		
	ElsIf TypeOf(TypeName) = Type("TypeDescription") Then
		
		TypeDescription = TypeName;
		
	EndIf;
	
	Return TypeDescription;
	
EndFunction // GetTypeDescription()

Procedure AdjustValueToTypeRestriction(Value, TypeRestriction, ChooseType = False) Export
	
	If TypeRestriction = Undefined Then
		Value = Undefined;
	Else	
		If Not TypeRestriction.ContainsType(TypeOf(Value)) Then
			If TypeRestriction.Types().Count() = 0 Then
				If Not ChooseType And Value <> Undefined Then
					Value = Undefined;
				EndIf;
			Else
				AdjustedValue = TypeRestriction.AdjustValue(Value);
				If Value <> AdjustedValue Then
					Value = AdjustedValue;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#If Client Then

Function SetUnsetMarkIncomplete(Control,AutoMarkIncomplete,Value) Export
	
	Control.AutoMarkIncomplete = AutoMarkIncomplete;
	Control.MarkIncomplete = Control.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction


Function SetControlMarkIncomplete(Control,Value) Export
	
	Control.AutoMarkIncomplete = Control.Enabled;
	Control.MarkIncomplete = Control.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction

Function SetControlMarkIncompleteAndEnable(Control, Value, Enabled) Export
	
	Control.Enabled = Enabled;
	Control.AutoMarkIncomplete = Control.Enabled;
	Control.MarkIncomplete = Control.AutoMarkIncomplete AND ValueIsNotFilled(Value);

EndFunction

#EndIf


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS WORKING WITH ERRORS

// Output error message on client or on server in the message window.
// In case of external Connection Raise is called.
//
// Parameters:
//  MessageText - String, message text.
//  Cancel      - boolean, cancellation flag.
//  Title       - String, message title, will output before message.
//  Status      - MessageStatus, message status, Important by default.
//
Procedure ErrorMessage(MessageText, Cancel = Undefined, Title = "", Status = Undefined, ObjectRef = Undefined) Export 
	
	If Status = Undefined Then
		Status = MessageStatus.Important;
	EndIf;
	
	MessageTextBegin    = Find(MessageText, "{");
	MessageTextEnd = Find(MessageText, "}:");
	If MessageTextEnd > 0 And MessageTextBegin > 0 Then
		MessageText = Left(MessageText, (MessageTextBegin - 1)) + Mid(MessageText, (MessageTextEnd + 2));
	EndIf;
	
	Cancel = True;
	
	#If ExternalConnection Then
		
		If Not IsBlankString(Title) Then
			MessageText = Title + Chars.LF + MessageText;
			Title = "";
		EndIf;
		
		Raise(MessageText);
		
	#Else
		
		#If Server Then
			
			If Status = MessageStatus.Important 
				OR Status = MessageStatus.VeryImportant Then
				
				LogEventStatus = EventLogLevel.Error;
				
			ElsIf Status = MessageStatus.Attention Then
				
				LogEventStatus = EventLogLevel.Warning;
				
			ElsIf Status = MessageStatus.Information Then	
				
				LogEventStatus = EventLogLevel.Information;
				
			Else	
				
				LogEventStatus = EventLogLevel.Note;
				
			EndIf;	
			
			WriteLogEvent("ServerErrorMessages",LogEventStatus, ?(ObjectRef = Undefined,ObjectRef,ObjectRef.Metadata()), ObjectRef ,?(Title<>"",Title + Chars.CR + Chars.LF,"") + MessageText,?(TransactionActive(),EventLogEntryTransactionMode.Transactional,EventLogEntryTransactionMode.Independent));
			
		#EndIf	
		
		If Not IsBlankString(Title) Then
			Message(Title);
			Title = "";
		EndIf;
		
		Message(MessageText, Status);
		
	#EndIf
	
EndProcedure // ErrorMessage()

Function GetErrorTextNotInStock(Available, Required, UnitOfMeasure, IsFree = False, IsReserved = False) Export 
	
	If IsFree Then
		Return Alerts.ParametrizeString(Nstr("en='Not enough quantity in stock (free, not reserved)! Only %P1 %P2 is available.';pl='Za mała ilość wolnego salda na magazynie! Tylko %P1 %P2 jest dostępne.'"),New Structure("P1, P2",Available,UnitOfMeasure));	
	ElsIf IsReserved Then
		Return Alerts.ParametrizeString(Nstr("en='Not enough quantity in stock (reserved for current document)! Only %P1 %P2 is available.';pl='Za mała ilość na magazynie zarezerwowana dla tego dokumentu! Tylko %P1 %P2 jest dostępne.'"),New Structure("P1, P2",Available,UnitOfMeasure));
	Else	
		Return Alerts.ParametrizeString(Nstr("en='Not enough quantity in stock! Only %P1 %P2 is available.';pl='Za mała ilość na magazynie! Tylko %P1 %P2 jest dostępne.'"),New Structure("P1, P2",Available,UnitOfMeasure));
	EndIf;	
	
EndFunction // GetErrorTextNotInStock()

Function GetLongDescription(Object) Export 
	
	If IsBlankString(Object.LongDescription) Then
		Return Object.Description;
	Else
		Return Object.LongDescription;
	EndIf;
	
EndFunction // GetLongDescription()

Function AmountInWords(Amount, Currency, LanguageCode = Undefined) Export
	
	If LanguageCode = Undefined Then
		FormatString = "L="+GetDefaultLanguageCodeAndDescription().LanguageCode+";";
		NumerationItemOptions = Currency.FormatStringPl;
	Else
		FormatString = "L=" + LanguageCode + ";";
		If upper(LanguageCode) = upper("ru") Then
			NumerationItemOptions = Currency.FormatStringRu;
		ElsIf upper(LanguageCode) = upper("en") Then	
			NumerationItemOptions = Currency.FormatStringEn;
		ElsIf upper(LanguageCode) = upper("pl") Then	
			NumerationItemOptions = Currency.FormatStringPl;	
		Else
			NumerationItemOptions = "";
		EndIf;
	EndIf;
	
	Return NumberInWords(Amount, FormatString, NumerationItemOptions);
	
EndFunction

Procedure UnderConstruction() Export
	
#If Client Then
	ShowMessageBox(, NStr("en='This option is temporary under construction.';pl='Ta opcja jest tymczasowo w fazie budowy.'"));
#Else
	Message(NStr("en='This option is temporary under construction.';pl='Ta opcja jest tymczasowo w fazie budowy.'"));
#EndIf
	
EndProcedure // UnderConstruction()

#If Client And ThickClientOrdinaryApplication Then
	
Function AskAboutTabularPartFilling() Export
		
	If DoQueryBox(Nstr("en=""Document's parameters were changed. Do you want to fill the tabular parts?"";pl='Parametry dokumentu zostały zmienione. Czy chcesz wypełnić częście tabelaryczne?';ru='Параметры документа были изменены. Хотите заполнить табличную часть?'"),QuestionDialogMode.YesNo) = DialogReturnCode.Yes Then
		Return True;
	Else
		Return False;
	EndIf;	
		
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR FILLING ATTRIBUTES IN FORM
// Jack 27.06.2017

//Procedure RegisterNewPartner(Control, Text, Value, StandardProcessing, mSupplierTyping, mSupplierTypingText, mLastValueOfSupplierTyping, ThisForm, Partner, Modified, CatalogName) Export

//	StandardProcessing = False;
//	
//	If TypeOf(Control.Value) <> Type("String") Then
//	
//		QueryText = NStr("en='Partner not found. Add new partner?';pl='Nie znaleziono partnera. Dodać nowego partnera?'");
//		
//		Answer = DoQueryBox(QueryText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.No);
//		
//		If Answer <> DialogReturnCode.Yes Then
//			If Answer = DialogReturnCode.No Then
//				mSupplierTyping = True;
//				mSupplierTypingText = Text;
//			Else
//				Value = mLastValueOfSupplierTyping;
//			EndIf;
//			Return;
//		EndIf;
//		
//		NewPartner = Catalogs[CatalogName].CreateItem();
//		SimplePartnerForm = NewPartner.GetForm("SimpleItemForm",ThisForm);
//		
//		IsPositiveNumber = False;
//		Try
//			RetNumb = Number(TrimAll(Text));
//			If RetNumb > 0 Then
//				IsPositiveNumber = True;
//			EndIf;
//		Except
//		EndTry;
//		
//		// if positive number then probably user creates partner by VATNumber
//		// else Text is treated like partner description
//		If IsPositiveNumber then
//			NewPartner.VATNumber = Text;
//			NewPartner.VATPayer = True;
//		Else 
//			NewPartner.Description = Text;
//			NewPartner.LongDescription = Text;
//		EndIf;
//		
//		SimplePartnerForm.DoModal();     
//		Value = Partner;
//		Modified = True;
//		
//	Else
//		
//		Value = Text;
//		
//	EndIf;
//	
//EndProcedure

//Procedure RegisterNewVendor(Control, Text, Value, StandardProcessing, mVendorTyping, mVendorTypingText, mLastValueOfVendorTyping, ThisForm, Vendor, Modified, CatalogName) Export

//	StandardProcessing = False;
//	
//	If TypeOf(Control.Value) <> Type("String") Then
//	
//		QueryText = NStr("en='Vendor not found. Add new vendor?';pl='Nie znaleziono producenta. Dodać nowego producenta?'");
//		
//		Answer = DoQueryBox(QueryText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.No);
//		
//		If Answer <> DialogReturnCode.Yes Then
//			If Answer = DialogReturnCode.No Then
//				mVendorTyping = True;
//				mVendorTypingText = Text;
//			Else
//				Value = mLastValueOfVendorTyping;
//			EndIf;
//			Return;
//		EndIf;
//		
//		NewVendor = Catalogs[CatalogName].CreateItem();
//		NewVendor.Description = Text;
//		NewVendor.Write();
//		
//		Value = NewVendor.Ref;
//		Modified = True;
//		
//	Else
//		
//		Value = Text;
//		
//	EndIf;
//	
//EndProcedure

//Procedure RegisterNewEmployee(Control, Text, Value, StandardProcessing, mEmployeeTyping, mEmployeeTypingText, mLastValueOfEmployeeTyping, ThisForm, Employee, Modified, CatalogName) Export

//	StandardProcessing = False;
//	
//	If TypeOf(Control.Value) <> Type("String") Then
//	
//		QueryText = NStr("en='Employee not found. Add new employee?';pl='Nie znaleziono pracownika. Dodać nowego pracownika?'");
//		
//		Answer = DoQueryBox(QueryText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.No);
//		
//		If Answer <> DialogReturnCode.Yes Then
//			If Answer = DialogReturnCode.No Then
//				mEmployeeTyping = True;
//				mEmployeeTypingText = Text;
//			Else
//				Value = mLastValueOfEmployeeTyping;
//			EndIf;
//			Return;
//		EndIf;
//		
//		NewEmployee = Catalogs[CatalogName].CreateItem();
//		SimpleEmployeeForm = NewEmployee.GetForm("ItemForm",ThisForm);
//		
//		NewEmployee.Description = Text;	
//		NewEmployee.CollaborationType = Enums.TypeOfCollaborationWithEmployee.Employee;
//		SimpleEmployeeForm.DoModal();     
//		Value = Employee;
//		Modified = True;		
//		
//	Else
//		
//		Value = Text;
//		
//	EndIf;
//	
//EndProcedure
#EndIf

// Procedure used to filling general form attributes
// Called from handlers on "OnOpen" events in all form modules in documents
//
// Parameters:
//  DocumentObject                 - editing document object
Procedure SetCatalogAttributeFromParent(AttributeName, CatalogObject) Export 
	
	AttributesTypes = CatalogObject.Metadata().Attributes[AttributeName].Type.Types();
	If (AttributesTypes.Count() = 1 AND AttributesTypes[0] = Type("Boolean"))
		OR ValueIsNotFilled(CatalogObject[AttributeName]) Then
		CatalogObject[AttributeName] = CatalogObject.Parent[AttributeName];
	EndIf;	
	
EndProcedure // SetCatalogAttributeFromParent()

/////////////////////////////////////////////////////////////////////////////////////////////////
/// Working with credit card
Function CheckCreditCardNumber(CardNumber) Export
	
	LenghtCardNumber = StrLen(CardNumber);
	Sum = 0;
    Digit = 0;
    AddEnd = 0;
	NumberIsZero = 0;
	
	If (LenghtCardNumber % 2) <> 0 Then
		TimesTwo = False;
	Else
		TimesTwo = True;
	EndIf;
	
	For i = 1 To LenghtCardNumber Do
		
		Digit = Number(Mid(CardNumber, i, 1));
		
		NumberIsZero = NumberIsZero + Digit;
		
		If TimesTwo Then
			AddEnd = Digit * 2;
			If AddEnd > 9 Then
          		AddEnd = AddEnd - 9;
	        EndIf;
      	Else
	        AddEnd = Digit;
		EndIf;
		
      	Sum = Sum + AddEnd;
      	TimesTwo = Not TimesTwo;
		
    EndDo;
	
	If NumberIsZero = 0 Then
		Return True;
	Else
		Modulus = Sum % 10;
		Return Not (Modulus = 0);
	EndIf;
	
EndFunction

Procedure GetObjectModificationFlag(Object) Export

   Object.AdditionalProperties.Insert("WasModified",Object.Modified());
   Object.AdditionalProperties.Insert("WasNew",Object.IsNew());
   Object.AdditionalProperties.Insert("WasPosted",Object.Posted);
   Object.AdditionalProperties.Insert("DocumentPresentation", String(Object) + "." + Chars.LF);
   Object.AdditionalProperties.Delete("IsCostError");

EndProcedure

Procedure LoadToValueTable(SourceTable, DestinationTable) Export

	// Fill values in same columns.
	For each SourceTableRow In SourceTable Do

		DestinationTableRow = DestinationTable.Add();
		FillPropertyValues(DestinationTableRow, SourceTableRow);

	EndDo;

EndProcedure // LoadToValueTable()

Function GetPeriodicityPresentation(PeriodicityType) Export
	
	If PeriodicityType = 2 Then
		// Day
		Return "DF = '" + NStr("corr='""Dzień""';en='""Day""';pl='""Dzień""'") + " dd.MM.yyyy '";
	ElsIf PeriodicityType = 3 Then	
		// Week
		Return "DF = '" + NStr("corr='""Tydzień od""';en='""Week from""';pl='""Tydzień od""'") + " dd.MM.yyyy '";
	ElsIf PeriodicityType = 4 Then	
		// TenDays
		Return "DF = '" + NStr("corr='""10 dni od""';en='""10 days from""';pl='""10 dni od""'") + " dd.MM.yyyy '";
	ElsIf PeriodicityType = 5 Then	
		// Month
		Return "DF = 'MMMM yyyy " + NStr("corr='""r.""';en='""y.""';pl='""r.""'") + "'";	
	ElsIf PeriodicityType = 6 Then	
		// Quarter
		Return "DF = 'q " + NStr("corr='""kwartał""';en='""quater""';pl='""kwartał""'") + " yyyy ""y.""'";		
	ElsIf PeriodicityType = 7 Then	
		// Half year
		Return "DF = '" + NStr("corr='""Pół roku od""';en='""Half year from""';pl='""Pół roku od""'") + " dd.MM.yyyy""'";			
	ElsIf PeriodicityType = 8 Then	
		// year
		Return "DF = 'yyyy " + NStr("corr='""r.""';en='""y.""';pl='""r.""'") + "'";				
	Else
		Return "dd.MM.yyyy HH:mm:ss";
	EndIf;	
	
EndFunction	

Function ExpandObjectCodeBySpaces(CodeInitial, ObjectsCodeLength) Export// Akulov
	RetCode = CodeInitial;
	CodeInitialLength = StrLen(RetCode);
	If CodeInitialLength < ObjectsCodeLength Then
		
		For CodeLength = CodeInitialLength + 1 To ObjectsCodeLength Do
				
				RetCode = RetCode + " ";
				
			EndDo;
			
		EndIf;
    Return RetCode;

EndFunction // ExpandObjectCodeBySpaces()


/////////////////////////////////////////////////////////////////////////////////////////////////
/// Working with strings

// Get tokens from string
// Tokens can be separated by , and ;
Function TokenizeString(val String) Export
	
	Tokens = New Array();
	EndOfString = StrLen(String)+1;
	i = 1;
	While i<>EndOfString Do
		
		Token = "";
		CurChar = "";
		While i<>EndOfString Do
			CurChar = Mid(String,i,1);
			If IsBlankString(CurChar) Then
				// space
				i = i+1;
			Else
				Break;
			EndIf;	
		EndDo;	
		
		If i = EndOfString Then
			Break;
		EndIf;	
		
		If CurChar = """" OR CurChar = "\" Then
			// read lexem between separators
			Quotation = CurChar;
			i = i+1;
			While i<>EndOfString Do
				CurChar = Mid(String,i,1);
				If CurChar = Quotation Then
					i = i+1;
					If (i=EndOfString OR Mid(String,i,1) = Quotation) Then
						Break;
					EndIf;	
				EndIf;
				Token = Token + Mid(String,i,1);
				i = i+1;
			EndDo;
			
			// skip spaces till separator
			If i<>EndOfString Then
				
				While True Do
					
					i = i+1;
					CurChar = Mid(String,i,1);
					
					If i<>EndOfString OR NOT IsBlankString(CurChar) Then
						Break;
					EndIf;	
					
				EndDo;	
				
			EndIf;	
			
		Else
			// read lexem before separator
			While i<>EndOfString Do
				
				CurChar = Mid(String,i,1);
				If CurChar = "," OR CurChar = ";" Then
					break;
				EndIf;
				Token = Token + CurChar;
				i = i+1;
				
			EndDo;
			Token = TrimR(Token);
		EndIf;	
		Tokens.Add(Token);
		If i<>EndOfString Then
			i= i+1;
		EndIf;	
	EndDo;	
	
	Return Tokens;
	
EndFunction	


/////////////////////////////////////////////////////////////////////////////////////////////////
//// ObjectSerialization

Function SerializeObject(Object, TypeAssignment = Undefined, XMLSerializer = False) Export
	If TypeAssignment = Undefined Then
		TypeAssignment = XMLTypeAssignment.Implicit 
	EndIf;
	XMLWriter = New XMLWriter();
	XMLWriter.SetString();
	If XMLSerializer Then
		WriteXML(XMLWriter, Object, TypeAssignment);
	Else
		XDTOSerializer.WriteXML(XMLWriter, Object, TypeAssignment);
	EndIf;
	XMLString = XMLWriter.Close();
	Return XMLString;
	
EndFunction

Function GetObjectFromXML(String,ObjectType, XMLSerializer = False) Export
	Result = Undefined;
	XMLReader = New XMLReader();
	XMLReader.SetString(String);
	If XMLSerializer Then
		Result =  ReadXML(XMLReader,ObjectType);
	Else
		Result = XDTOSerializer.ReadXML(XMLReader,ObjectType);
	EndIf;
	Return Result;
EndFunction	

Function GetSearchSubStringsArray(FastFilter)
	
	PrevSpacePos = 0;
	SearchStringsArray = New Array;
	For i = 1 to StrLen(FastFilter) Do
		If Mid(FastFilter, i, 1) = " " Then
			If i - PrevSpacePos > 1 Then
				SearchStringsArray.Add(Mid(FastFilter, PrevSpacePos + 1, i - PrevSpacePos - 1));
			EndIf;
			PrevSpacePos = i;
		EndIf;
	EndDo;
	
	If i - PrevSpacePos > 1 Then
		SearchStringsArray.Add(Mid(FastFilter, PrevSpacePos + 1, i - PrevSpacePos - 1));
	EndIf;
	
	Return SearchStringsArray;
	
EndFunction	

Function IsFullTextSearchSpecialSymbolInWord(Word) Export
	
	SpecialSymbolsArray = New Array();
	SpecialSymbolsArray.Add(" AND ");
	SpecialSymbolsArray.Add(" OR ");
	SpecialSymbolsArray.Add(" NOT ");
	SpecialSymbolsArray.Add(" NEAR/");
	SpecialSymbolsArray.Add("#");
	SpecialSymbolsArray.Add("""");
	SpecialSymbolsArray.Add("!");
	SpecialSymbolsArray.Add("*");
	SpecialSymbolsArray.Add("(");
	SpecialSymbolsArray.Add(")");
	SpecialSymbolsArray.Add("|");
	SpecialSymbolsArray.Add("-)");
	SpecialSymbolsArray.Add("~");
	SpecialSymbolsArray.Add("-");
	
	ReturnValue = False;
	
	For Each SpecialSymbol In SpecialSymbolsArray Do
		
		If Find(Word,SpecialSymbol)>0 Then
			Return True;
		EndIf;	
		
	EndDo;	
	
	WasException = False;
	Try
		Num = Number(Word);
	Except
		WasException = True;
	EndTry;
	
	If Not WasException Then
		Return True;
	EndIf;	
	
	Return ReturnValue;
	
EndFunction	

Function GetDefaultLanguageCodeAndDescription() Export
	
	Return New Structure("LanguageCode, Description","pl", NStr("en = 'Polish'; pl = 'Polski'; ru = 'Польский'"));
	
EndFunction

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#If Client And ThickClientOrdinaryApplication Then
Procedure CommonDateOnChange(Control,ThisForm,ThisObject,IsArchive = False) Export
	
	CommonDocumentDateControl(Control,ThisForm,ThisObject);
	CommonDocumentNumberControl(Control,ThisForm,ThisObject,IsArchive);
	
EndProcedure	

Procedure CommonDocumentFormOnOpenBegin(ThisForm,ThisObject) Export
	
	ThisObject.AdditionalProperties.Insert("EditingInForm", ThisForm);
	
EndProcedure	

Procedure CommonDocumentFormOnOpenEnd(ThisForm,ThisObject) Export
	
	Dialogs.AddFormMainActionsBookkeepingButton(ThisForm);	
	DocumentsPostingAndNumbering.CheckEditingPermission(ThisForm);
	DocumentsPostingAndNumbering.CheckEditingPermissionForArchive(ThisForm);
	Printouts.SetQuickPrintHandler(ThisForm);
	CommonDocumentDateControl(ThisForm.Controls.Date,ThisForm,ThisObject);
	
EndProcedure	

Procedure CommonDocumentDateControl(Control,ThisForm,ThisObject) Export
	
	If ThisObject.Date>GetServerDate() Then
		
		If ThisObject.Metadata().RealTimePosting = Metadata.ObjectProperties.RealTimePosting.Allow Then
			Control.FieldBackColor = StyleColors.NegativeTextColor;
			Control.Tooltip = Nstr("en = 'The future date is set! Please, chek is it correct.'; pl = 'Ustawiona data przyszła! Sprawdź czy to jest poprawnie.'");
		Else	
			
			If ThisForm.IsNew() Then
				Answer = DoQueryBox(Nstr("en = 'The future date was set. Are you sure you want to set the future date?'; pl = 'Została ustawiona przyszła data. Czy na pewno chcesz ustawić przyszłą datę?'"),QuestionDialogMode.YesNo);
				If Answer = DialogReturnCode.No Then
					ThisObject.Date = GetServerDate();
				Else
					Control.FieldBackColor = StyleColors.YellowColor;
					Control.Tooltip = Nstr("en = 'The future date is set! Please, chek is it correct.'; pl = 'Ustawiona data przyszła! Sprawdź czy to jest poprawnie.'");
				EndIf;
			Else
				Control.FieldBackColor = StyleColors.YellowColor;
				Control.Tooltip = Nstr("en = 'The future date is set! Please, chek is it correct.'; pl = 'Ustawiona data przyszła! Sprawdź czy to jest poprawnie.'");
			EndIf;
		
		EndIf;	
	Else
		Control.FieldBackColor = StyleColors.FieldBackColor;
		Control.Tooltip = "";
	EndIf;	
	
EndProcedure	

Procedure CommonDocumentNumberControl(Control,ThisForm,ThisObject,IsArchive = False) Export
	
	If ThisForm.Controls.Number.Data = "" AND NOT IsArchive Then
		ThisForm.Controls.Number.Value = DocumentsPostingAndNumbering.GetDocumentAutoNumberPresentation(ThisObject);
	EndIf;
	
EndProcedure	
#EndIf

////////////////////////////////////////////////////////////////////////////////
////// Free days counter

Function DaySeconds() Export
	Return 86400;
EndFunction

Function GetEasterStructure()
	
	EasterStructure = New Structure();
	EasterStructure.Insert("y2008",'2008.03.23');
	EasterStructure.Insert("y2009",'2009.04.12');
	EasterStructure.Insert("y2010",'2010.04.04');
	EasterStructure.Insert("y2011",'2011.04.24');
	EasterStructure.Insert("y2012",'2012.04.08');
	EasterStructure.Insert("y2013",'2013.03.31');
	EasterStructure.Insert("y2014",'2014.04.20');
	EasterStructure.Insert("y2015",'2015.04.05');
	EasterStructure.Insert("y2016",'2016.03.27');
	EasterStructure.Insert("y2017",'2017.04.16');
	EasterStructure.Insert("y2018",'2018.04.01');
	EasterStructure.Insert("y2019",'2018.04.21');
	EasterStructure.Insert("y2020",'2018.04.12');
	EasterStructure.Insert("y2021",'2018.04.04');
	EasterStructure.Insert("y2022",'2018.04.17');
	EasterStructure.Insert("y2023",'2018.04.09');
	EasterStructure.Insert("y2024",'2018.03.31');
	EasterStructure.Insert("y2025",'2018.04.20');
	EasterStructure.Insert("y2026",'2018.04.05');
	
	return EasterStructure;
	
EndFunction

Function IsFreeDay(Val Date,SaturdayIsFree = False) Export
	
	Date = BegOfDay(Date);
	// niedziele
	If WeekDay(Date) = 7 Then
		Return True;	
	EndIf;
	
	If SaturdayIsFree AND WeekDay(Date) = 6 Then
		Return True;
	EndIf;	
	
	Year = Year(Date);
	Month = Month(Date);
	Day = Day(Date);
	
	// święta nieruchome
	If (Month = 1 AND Day = 1) // Nowy Rok
		OR (Month = 1 AND Day = 6 AND Year>2011) // Trzech Króli
		OR (Month = 5 AND Day = 1) // Pierwsze maja
		OR (Month = 5 AND Day = 3) // Święto trzeciego maja
		OR (Month = 8 AND Day = 15) // Wniebowzięcie Najświętszej Maryi Panny
		OR (Month = 11 AND Day = 1) // Wszystkich Świętych
		OR (Month = 11 AND Day = 11) // Narodowe Święto Niepodległości
		OR (Month = 12 AND Day = 25) // pierwszy dzień Bożego Narodzenia
		OR (Month = 12 AND Day = 26) // drugi dzień Bożego Narodzenia
		Then
		Return True;
	EndIf;	
	
	// święta ruchome
	// Wielkanoc	
	EasterStructure = GetEasterStructure();
	FoundEasterDay = EasterStructure["y"+Format(Year,"NG=0")];
	If Date = FoundEasterDay // Pierwszy dzień Wielkiej Nocy
		Or Date = FoundEasterDay+DaySeconds()  // Drugi dzień Wielkiej Nocy
		Or Date = FoundEasterDay+49*DaySeconds() // Pierwszy dzień Zielonych Świątek
		Or Date = FoundEasterDay+60*DaySeconds() // Dzień Bożego Ciała
		Then
		Return True;
	EndIf;	
	
	Return False;
	
EndFunction

Function GetNearestWorkDayDate(Val Date) Export
	// returns given date if it's work date	
	Date = BegOfDay(Date);
	While True Do
		
		If IsFreeDay(Date) Then
			Date = Date + DaySeconds();
		Else
			Break;
		EndIf;	
				
	EndDo;	
	
	Return Date;
	
EndFunction	

Function GetOverdueDaysCount(Val DateFrom, Val DateTo,Val SkipFreeDay = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	DateTo = BegOfDay(DateTo);
	
	If SkipFreeDay Then
		While DateFrom<DateTo Do
			
			If IsFreeDay(DateFrom) Then
				DateFrom = DateFrom + DaySeconds();
			Else
				Break;
			EndIf;	
			
		EndDo;	
	EndIf;
	
	Return ((DateTo-DateFrom)/DaySeconds())+1;
	
EndFunction	

Function GetYearDays(Date = Undefined) Export
	
	Return 365;
	
EndFunction	

Function GetCompanyLogo(Company) Export
	
	//Return CommonAtServer.GetCompanyLogo(Company);
	// Jack 29.06.2017
	// to do
	Return Undefined;
EndFunction

// Jack 29.06.2017
//Function GetPaymentDate(InitialDate, PaymentTerm) Export
//	Return CommonAtServer.GetPaymentDate(InitialDate, PaymentTerm);
//EndFunction

Function GetExchangeRateRecord(Currency, RateDate) Export
	Return CommonAtServer.GetExchangeRateRecord(Currency, RateDate);
EndFunction

Function GetExchangeRate(Currency, RateDate) Export
	Return CommonAtServer.GetExchangeRate(Currency, RateDate);
EndFunction

Function GetDocumentExchangeRateDate(DocumentObject, UseAccountingPolicyExchangeRateDateForCalculatingSalesAndPurchase = False,AlternateDate = Undefined) Export
	Return CommonAtServer.GetDocumentExchangeRateDate(DocumentObject, UseAccountingPolicyExchangeRateDateForCalculatingSalesAndPurchase, AlternateDate);
EndFunction

Function GetExchangeRateDifferencePolicy(Date, Company, Sing, CarriadOut, Group) Export
	Return CommonAtServer.GetExchangeRateDifferencePolicy(Date, Company, Sing, CarriadOut, Group);
EndFunction

Function IsDocumentAttribute(AttributeName, DocumentMetadata) Export
	Return CommonAtServer.IsDocumentAttribute(AttributeName, DocumentMetadata);
EndFunction

Function GetEnumNameByValue(EnumValue) Export
	Return CommonAtServer.GetEnumNameByValue(EnumValue);
EndFunction

Function GetNationalAmount(Amount, Currency, ExchangeRate) Export
	Return CommonAtServer.GetNationalAmount(Amount, Currency, ExchangeRate);
EndFunction

// Jack 27.06.2017
//Function CreateNewInternalDocument(Control, Text, Value, StandardProcessing, mSupplierTyping, mSupplierTypingText, mLastValueOfSupplierTyping, ThisForm, Modified, CatalogName,TabularPartName = "SettlementDocuments",Owner = Undefined,OmitQuestionOnNewCreation = False) Export
//	Return CommonAtServer.CreateNewInternalDocument(Control, Text, Value, StandardProcessing, mSupplierTyping, mSupplierTypingText, mLastValueOfSupplierTyping, ThisForm, Modified, CatalogName, TabularPartName, Owner, OmitQuestionOnNewCreation);
//EndFunction

//Function GetItemsUnitsOfMeasureValueList(Item) Export
//	Return CommonAtServer.GetItemsUnitsOfMeasureValueList(Item);
//EndFunction

//Function IsCreditCardInSystem(CardNumber, PaymentMetodResult = Undefined) Export
//	Return CommonAtServer.IsCreditCardInSystem(CardNumber, PaymentMetodResult);
//EndFunction

Function GetGeneratedByText(LanguageCode = "") Export
	Return CommonAtServer.GetGeneratedByText(LanguageCode);
EndFunction

Function GetUserSettingsValue(Setting = "", User = Undefined) Export
	Return CommonAtServer.GetUserSettingsValue(Setting, User);
EndFunction
// Jack 27.06.2017
//Function GetDocumentRemarks(DocumentObject, BusinessPartner = Undefined) Export
//	Return CommonAtServer.GetDocumentRemarks(DocumentObject, BusinessPartner);
//EndFunction

//Function DocumentsAcceptance_DataCompositionSettingsComposer(DocumentBase) Export
//	Return CommonAtServer.DocumentsAcceptance_DataCompositionSettingsComposer(DocumentBase);
//EndFunction

//Function DocumentsAcceptance_GetSchemaRef(DocumentRef, ErrorText) Export
//	Return CommonAtServer.DocumentsAcceptance_GetSchemaRef(DocumentRef, ErrorText);
//EndFunction

//Function CustomersFastFilter(FastFilter, PortionSize = 100,GetDescription = False,AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//	Return CommonAtServer.CustomersFastFilter(FastFilter, PortionSize,GetDescription, AskAboutCountOfGettingPortions, GetAllPortions);
//EndFunction

//Function ItemsFastFilter(FastFilter,PortionSize = 100,GetDescription = False,AskAboutCountOfGettingPortions = False, GetAllPortions = True) Export
//	Return CommonAtServer.ItemsFastFilter(FastFilter, PortionSize, GetDescription, AskAboutCountOfGettingPortions, GetAllPortions);
//EndFunction

Function GetAttribute(ObjectRef,AttributeName,Cancel = False) Export
	Return CommonAtServer.GetAttribute(ObjectRef,AttributeName,Cancel);
EndFunction

Function GetLastFinancialYear() Export
	Return CommonAtServer.GetLastFinancialYear();
EndFunction

Function GetSiteStructure(Val StrLink) Export
	
	StrLink = TrimAll(StrLink); 
	
	HTTPServer		 		= ""; 
	HTTPPort				= 0;
	HTTPScriptLink 			= "";
	HTTPSecureConnection 	= False;
	
	If ValueIsFilled(StrLink) Then
		
		StrLink = StrReplace(StrLink, "\", "/");
		StrLink = StrReplace(StrLink, " ", "");
		
		If Upper(Left(StrLink, 7)) = "HTTP://" Then
			StrLink = Mid(StrLink, 8);
		ElsIf Upper(Left(StrLink, 8)) = "HTTPS://" Then
			StrLink = Mid(StrLink, 9);
			HTTPSecureConnection = True;
		EndIf;
		
		SlashPosition = Find(StrLink, "/");
		
		If SlashPosition > 0 Then
			HTTPServer 		 = Left(StrLink, SlashPosition - 1);
			HTTPScriptLink = Right(StrLink, СтрДлина(StrLink) - SlashPosition);
		Else	
			HTTPServer 		 = StrLink;
			HTTPScriptLink = "";
		EndIf;
		ColonPosition = Find(HTTPServer, ":");
		If ColonPosition > 0 Then
			HTTPServerPort = HTTPServer;
			HTTPServer		  = Left(HTTPServerPort, ColonPosition - 1);
			HTTPPortString 	  = Right(HTTPServerPort, StrLen(HTTPServerPort) - ColonPosition);
		Иначе
			HTTPPortString = "0";
		КонецЕсли;
		
		HTTPPort = Number(HTTPPortString);
		
	КонецЕсли;
	
	HTTPPort = ?(HTTPPort = 0, ?(HTTPSecureConnection, 443, 80), HTTPPort);
	
	ResultStructure = New Structure;
	ResultStructure.Insert("HTTPServer"	  			, HTTPServer); 
	ResultStructure.Insert("HTTPPort"		   		, HTTPPort);
	ResultStructure.Insert("HTTPScriptLink"			, HTTPScriptLink);
	ResultStructure.Insert("HTTPSecureConnection"	, HTTPSecureConnection);
	
	Return ResultStructure;
	
EndFunction


