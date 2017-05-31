
Function Accept(Document, Comment, ErrorMessage, DateTime = Undefined, Action = Undefined,User = Undefined) Export
	
	If Not Document.Posted Then
		ErrorMessage = NStr("en = 'Acceptation operations could be performed only with posted documents. This document hasn''t been posted.'; pl = 'Operacje akceptacji mogą być przeprowadzone tylko dla zatwierdzonych dokumentów. Ten dokument nie jest zatwierdzony.'");
		Return False;
	EndIf;
	
	SchemaTable = GetSchemaTable(Document);
	If SchemaTable.Count() = 0 Then
		Return True;
	ElsIf ValueIsNotFilled(SchemaTable[0].Schema) Then
		ErrorMessage = NStr("en = 'Document doesn''t need acceptation.'; pl = 'Dokument nie wymaga akceptacji.'");
		Return False;
	EndIf;
	
	CurrentUser = ?(User = Undefined,SessionParameters.CurrentUser,User);
	CurrentSchema = SchemaTable[0].Schema;
	
	// First check if user is in the schema.
	UsersStructure = GetNextUserInSchema(CurrentUser, SchemaTable);
	If UsersStructure.NextUser = Undefined Then
		
		// Then check author. Author can always accept his documents.
		If CurrentUser = Document.Author Then
			UsersStructure.NextUser = SchemaTable[0].User;
		Else
			ErrorMessage = NStr("en = 'You cann''t accept this document. You are not in the acceptance schema.'; pl = 'Nie możesz zaakceptować ten dokument. Nie jesteś w schemacie akceptacji.'");
			Return False;
		EndIf;
		
	EndIf;
	
	Record = InformationRegisters.DocumentsAcceptance.CreateRecordManager();
	Record.Period = ?(DateTime = Undefined, GetRealTimeTimestamp(), DateTime);
	Record.Document = Document;
	Record.Schema = CurrentSchema;
	Record.User = CurrentUser;
	Record.Action = ?(Action = Undefined, Enums.DocumentsAcceptanceActions.Accepted, Action);
	Record.Comment = Comment;
	Record.NextUser = UsersStructure.NextUser;
	Record.SubstitutedUser = UsersStructure.SubstitutedUser;
	
	DocumentMetadata = Document.Metadata();
	Record.DocumentType = Documents[DocumentMetadata.Name].EmptyRef();
	If CommonAtServer.IsDocumentAttribute("Company", DocumentMetadata) Then
		Record.Company = Document.Company;
	EndIf;
	
	Try
		Record.Write(False);
		Return True;
	Except
		ErrorMessage = NStr("en = 'Acceptance list record write was unsuccessful.'; pl = 'Nie udało się zrobić wpis do listy akceptacji.'") + Chars.LF + ErrorInfo().Description;
		Return False;
	EndTry;
	
EndFunction

Function Refuse(Document, Comment, ErrorMessage, DateTime = Undefined) Export
	
	If Not Document.Posted Then
		ErrorMessage = NStr("en = 'Acceptation operations could be performed only with posted documents. This document hasn''t been posted.'; pl = 'Operacje akceptacji mogą być przeprowadzone tylko dla zatwierdzonych dokumentów. Ten dokument nie jest zatwierdzony.'");
		Return False;
	EndIf;
	
	CurrentUser = SessionParameters.CurrentUser;
	
	If CurrentUser = Document.Author Then
		ErrorMessage = NStr("en = 'The author of the document cann''t refuse acceptaction.'; pl = 'Autor dokumentu nie może odmówić akceptacji.'");
		Return False;
	EndIf;
	
	SchemaTable = GetSchemaTable(Document);
	If SchemaTable.Count() = 0
		OR ValueIsNotFilled(SchemaTable[0].Schema) Then
		//Document doesn''t need acceptation.
		Return True;
	EndIf;
	
	CurrentSchema = SchemaTable[0].Schema;
	
	CurrentStateStructure = GetCurrentState(Document);
	If CurrentStateStructure = Undefined Then
		ErrorMessage = NStr("en = 'This document doesn''t have acceptance process running.'; pl = 'Ten dokument nie ma uruchomianego procesu akceptacji.'");
		Return False;
	EndIf;
	
	If CurrentStateStructure.NextUser <> CurrentUser And GetSubstituteUser(CurrentStateStructure.NextUser, CurrentSchema) <> CurrentUser Then
		If CurrentStateStructure.User = CurrentUser Or GetSubstituteUser(CurrentStateStructure.User, CurrentSchema) = CurrentUser Then
			ErrorMessage = NStr("en = 'You''ve just accepted this document. To refuse acceptation first cancel your accept.'; pl = 'Dopiero zaakceptowałeś ten dokument. Żeby odmówić akceptacji najpierw anuluj swoją akceptację.'");
		Else
			ErrorMessage = NStr("en = 'You can refuse acceptation only if you are the next user in schema.'; pl = 'Możesz odmówić akceptacji tylko jeśli jesteś następnym użytkownikiem w schemacie.'");
		EndIf;
		Return False;
	EndIf;
	
	UsersStructure = GetPreviousUserInSchema(CurrentUser, SchemaTable);
	If UsersStructure.PreviousUser = Undefined Then
		ErrorMessage = NStr("en = 'You cann''t refuse acceptation for this document. You are not in the acceptance schema.'; pl = 'Nie możesz odmówić akceptacji tego dokumentu. Nie jesteś w schemacie akceptacji.'");
		Return False;
	ElsIf UsersStructure.PreviousUser.IsEmpty() Then
		UsersStructure.PreviousUser = Document.Author;
	EndIf;
	
	Record = InformationRegisters.DocumentsAcceptance.CreateRecordManager();
	Record.Period = ?(DateTime = Undefined, GetRealTimeTimestamp(), DateTime);
	Record.Document = Document;
	Record.Schema = CurrentSchema;
	Record.User = CurrentUser;
	Record.Action = Enums.DocumentsAcceptanceActions.Refused;
	Record.Comment = Comment;
	Record.NextUser = UsersStructure.PreviousUser;
	Record.SubstitutedUser = UsersStructure.SubstitutedUser;
	
	DocumentMetadata = Document.Metadata();
	Record.DocumentType = Documents[DocumentMetadata.Name].EmptyRef();
	If CommonAtServer.IsDocumentAttribute("Company", DocumentMetadata) Then
		Record.Company = Document.Company;
	EndIf;
	
	Try
		Record.Write(False);
		Return True;
	Except
		ErrorMessage = NStr("en = 'Acceptance list record write was unsuccessful.'; pl = 'Nie udało się zrobić wpis do listy akceptacji.'") + Chars.LF + ErrorInfo().Description;
		Return False;
	EndTry;
	
EndFunction

Function Cancel(Document, ErrorMessage) Export
	
	If Not Document.Posted Then
		ErrorMessage = NStr("en = 'Acceptation operations could be performed only with posted documents. This document hasn''t been posted.'; pl = 'Operacje akceptacji mogą być przeprowadzone tylko dla zatwierdzonych dokumentów. Ten dokument nie jest zatwierdzony.'");
		Return False;
	EndIf;
	
	CurrentUser = SessionParameters.CurrentUser;
	If CurrentUser = Document.Author Then
		ErrorMessage = NStr("en = 'The author of the document cann''t cancel acceptaction.'; pl = 'Autor dokumentu nie może anulować akceptację.'");
		Return False;
	EndIf;
	
	CurrentStateStructure = GetCurrentState(Document);
	If CurrentStateStructure = Undefined Then
		ErrorMessage = NStr("en = 'This document doesn''t have acceptance process running.'; pl = 'Ten dokument nie ma uruchomianego procesu akceptacji.'");
		Return False;
	EndIf;
	
	If CurrentStateStructure.User <> CurrentUser And GetSubstituteUser(CurrentStateStructure.User, CurrentStateStructure.Schema) <> CurrentUser Then
		ErrorMessage = NStr("en = 'You can cancel your acceptation only if you are the current user in schema.'; pl = 'Możesz anulować swoją akceptację tylko jeśli jesteś bieżącym użytkownikiem w schemacie.'");
		Return False;
	EndIf;
	
	Record = InformationRegisters.DocumentsAcceptance.CreateRecordManager();
	Record.Period = CurrentStateStructure.Period;
	Record.Document = Document;
	Record.Read();
	
	If Record.Action <> Enums.DocumentsAcceptanceActions.Accepted And Record.Action <> Enums.DocumentsAcceptanceActions.Refused Then
		ErrorMessage = NStr("en = 'You can''t cancel acceptation if it was set on posting.'; pl = 'Nie możesz anulować akceptacji jeśli została utworzona przy zatwierdzeniu.'");
		Return False;
	EndIf;
	
	Try
		Record.Delete();
		Return True;
	Except
		ErrorMessage = NStr("en = 'Acceptance list record deletion was unsuccessful.'; pl = 'Nie udało się usunąć wpis z listy akceptacji.'") + Chars.LF + ErrorInfo().Description;
		Return False;
	EndTry;
	
EndFunction


Function SetAcceptanceSchema(Document, Schema, ErrorMessage, DateTime) Export
	
	RecordSet = InformationRegisters.DocumentsAcceptanceSchemas.CreateRecordSet();
	RecordSet.Filter.Document.Set(Document);
	RecordSet.Filter.Period.Set(DateTime);
	
	For Each UsersRow In Schema.SchemaUsers Do
		
		Record = RecordSet.Add();
		Record.Period = DateTime;
		Record.Document = Document;
		Record.UserOrder = UsersRow.LineNumber;
		Record.User = UsersRow.User;
		Record.Schema = Schema;
		
	EndDo;
	
	Try
		RecordSet.Write(False);
	Except
		ErrorMessage = NStr("en = 'Acceptance schemas record write was unsuccessful.'; pl = 'Nie udało się zrobić wpis schematów akceptacji.'") + Chars.LF + ErrorInfo().Description;
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function ClearAcceptanceSchema(Document, ErrorMessage, User, Action, DateTime) Export
	
	CurrentStateStructure = GetCurrentState(Document);
	If CurrentStateStructure <> Undefined And ValueIsFilled(CurrentStateStructure.Schema) Then
		
		Record = InformationRegisters.DocumentsAcceptance.CreateRecordManager();
		Record.Period = DateTime;
		Record.Document = Document;
		Record.Schema = Undefined;
		Record.User = User;
		Record.Action = Action;
		Record.Comment = Undefined;
		Record.NextUser = Undefined;
		
		DocumentMetadata = Document.Metadata();
		Record.DocumentType = Documents[DocumentMetadata.Name].EmptyRef();
		If CommonAtServer.IsDocumentAttribute("Company", DocumentMetadata) Then
			Record.Company = Document.Company;
		EndIf;
		
		Try
			Record.Write(False);
		Except
			ErrorMessage = NStr("en = 'Acceptance record write was unsuccessful.'; pl = 'Nie udało się zrobić wpis akceptacji.'") + Chars.LF + ErrorInfo().Description;
			Return False;
		EndTry;
		
	EndIf;
	
	SchemaTable = GetSchemaTable(Document);
	If SchemaTable.Count() > 0 And ValueIsFilled(SchemaTable[0].Schema) Then
		
		Record = InformationRegisters.DocumentsAcceptanceSchemas.CreateRecordManager();
		Record.Period = DateTime;
		Record.Document = Document;
		Record.UserOrder = 1;
		Record.User = Undefined;
		Record.Schema = Undefined;
		
		Try
			Record.Write(False);
		Except
			ErrorMessage = NStr("en = 'Acceptance schemas record write was unsuccessful.'; pl = 'Nie udało się zrobić wpis schematów akceptacji.'") + Chars.LF + ErrorInfo().Description;
			Return False;
		EndTry;
		
	EndIf;
	
	Return True;
	
EndFunction


Function GetSchemaTable(Document) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	DocumentsAcceptanceSchemas.Period AS Period,
	             |	DocumentsAcceptanceSchemas.UserOrder AS UserOrder,
	             |	DocumentsAcceptanceSchemas.User AS User,
	             |	DocumentsAcceptanceSchemas.Schema AS Schema,
	             |	DocumentsAcceptanceSubstituteUsers.SubstituteUser AS SubstituteUser
	             |FROM
	             |	InformationRegister.DocumentsAcceptanceSchemas AS DocumentsAcceptanceSchemas
	             |		LEFT JOIN InformationRegister.DocumentsAcceptanceSubstituteUsers AS DocumentsAcceptanceSubstituteUsers
	             |		ON DocumentsAcceptanceSchemas.User = DocumentsAcceptanceSubstituteUsers.User
	             |			AND DocumentsAcceptanceSchemas.Schema = DocumentsAcceptanceSubstituteUsers.Schema
	             |			AND (DocumentsAcceptanceSubstituteUsers.DateFrom <= &Date)
	             |			AND (DocumentsAcceptanceSubstituteUsers.DateTo >= &Date)
	             |WHERE
	             |	DocumentsAcceptanceSchemas.Document = &Document
	             |	AND DocumentsAcceptanceSchemas.Period IN
	             |			(SELECT
	             |				MAX(DocumentsAcceptanceSchemas.Period) AS Period
	             |			FROM
	             |				InformationRegister.DocumentsAcceptanceSchemas AS DocumentsAcceptanceSchemas
	             |			WHERE
	             |				DocumentsAcceptanceSchemas.Document = &Document)
	             |
	             |ORDER BY
	             |	UserOrder";
	
	Query.SetParameter("Document", Document);
	Query.SetParameter("Date", BegOfDay(CurrentDate()));
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetCurrentState(Document) Export
	
	If Document.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	DocumentsAcceptanceSliceLast.Period,
	             |	DocumentsAcceptanceSliceLast.Schema,
	             |	DocumentsAcceptanceSliceLast.User,
	             |	DocumentsAcceptanceSliceLast.Action,
	             |	DocumentsAcceptanceSliceLast.Comment,
	             |	DocumentsAcceptanceSliceLast.NextUser
	             |FROM
	             |	InformationRegister.DocumentsAcceptance.SliceLast(, Document = &Document) AS DocumentsAcceptanceSliceLast";
	
	Query.SetParameter("Document", Document);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Structure = New Structure;
	Structure.Insert("Period", Selection.Period);
	Structure.Insert("Schema", Selection.Schema);
	Structure.Insert("User", Selection.User);
	Structure.Insert("Action", Selection.Action);
	Structure.Insert("Comment", Selection.Comment);
	Structure.Insert("NextUser", Selection.NextUser);
	
	Return Structure;
	
EndFunction

Function GetNextUserInSchema(User, SchemaTable)
	
	Structure = New Structure("NextUser, SubstitutedUser");
	
	SubstituteUserRows = SchemaTable.FindRows(New Structure("SubstituteUser", User));
	
	SchemaTableRow = SchemaTable.Find(User, "User");
	For Each SubstituteUserRow In SubstituteUserRows Do
		If SchemaTableRow = Undefined Then
			SchemaTableRow = SubstituteUserRow;
		ElsIf SchemaTableRow.UserOrder < SubstituteUserRow.UserOrder Then
			SchemaTableRow = SubstituteUserRow;
		EndIf;
	EndDo;
	
	If SchemaTableRow = Undefined Then // didn't find user
		Return Structure;
	EndIf;
	
	If SchemaTableRow.SubstituteUser = User Then
		Structure.SubstitutedUser = SchemaTableRow.User;
	EndIf;
	
	FoundRowIndex = SchemaTable.IndexOf(SchemaTableRow);
	If FoundRowIndex = SchemaTable.Count() - 1 Then // the last user in schema
		Structure.NextUser = Catalogs.Users.EmptyRef();
	Else
		Structure.NextUser = SchemaTable[FoundRowIndex + 1].User;
	EndIf;
	
	Return Structure;
	
EndFunction

Function GetPreviousUserInSchema(User, SchemaTable)
	
	Structure = New Structure("PreviousUser, SubstitutedUser");
	
	SubstituteUserRows = SchemaTable.FindRows(New Structure("SubstituteUser", User));
	
	SchemaTableRow = SchemaTable.Find(User, "User");
	For Each SubstituteUserRow In SubstituteUserRows Do
		If SchemaTableRow = Undefined Then
			SchemaTableRow = SubstituteUserRow;
		ElsIf SchemaTableRow.UserOrder > SubstituteUserRow.UserOrder Then
			SchemaTableRow = SubstituteUserRow;
		EndIf;
	EndDo;
	
	If SchemaTableRow = Undefined Then // didn't find user
		Return Structure;
	EndIf;
	
	If SchemaTableRow.SubstituteUser = User Then
		Structure.SubstitutedUser = SchemaTableRow.User;
	EndIf;
	
	FoundRowIndex = SchemaTable.IndexOf(SchemaTableRow);
	If FoundRowIndex = 0 Then // the first user in schema
		Structure.PreviousUser = Catalogs.Users.EmptyRef();
	Else
		Structure.PreviousUser = SchemaTable[FoundRowIndex - 1].User;
	EndIf;
	
	Return Structure;
	
EndFunction

Function GetSubstituteUser(User, Schema)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	DocumentsAcceptanceSubstituteUsers.SubstituteUser AS SubstituteUser
	             |FROM
	             |	InformationRegister.DocumentsAcceptanceSubstituteUsers AS DocumentsAcceptanceSubstituteUsers
	             |WHERE
	             |	DocumentsAcceptanceSubstituteUsers.User = &User
	             |	AND DocumentsAcceptanceSubstituteUsers.Schema = &Schema
	             |	AND DocumentsAcceptanceSubstituteUsers.DateFrom >= &Date
	             |	AND DocumentsAcceptanceSubstituteUsers.DateTo <= &Date";
	
	Query.SetParameter("User", User);
	Query.SetParameter("Schema", Schema);
	Query.SetParameter("Date", BegOfDay(CurrentDate()));
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.SubstituteUser;
	EndIf;
	
EndFunction

Function GetDocumentsTypesList() Export
	
	Array = New Array;
	For Each Type In Metadata.EventSubscriptions.DocumentsPostingAcceptance.Source.Types() Do
		
		Object = New (Type);
		MetadataObject = Object.Metadata();
		
		Array.Add(MetadataObject.Name);
		
	EndDo;
	
	Return Array;
	
EndFunction

Function GetDocumentsTypesWithAcceptanceList() Export
	
	Array = New Array;
	Query = New Query;
	Query.Text = "SELECT
	             |	DocumentsAcceptanceSettings.DocumentType
	             |FROM
	             |	InformationRegister.DocumentsAcceptanceSettings AS DocumentsAcceptanceSettings
	             |WHERE
	             |	DocumentsAcceptanceSettings.UseAcceptance";
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		MetadataObject = Selection.DocumentType.Metadata();
		
		Array.Add(MetadataObject.Name);
		
	EndDo;
	
	Return Array;
	
EndFunction


Function Accepted(Document) Export
	
	NextUser = NextUser(Document);
	
	Return Not ValueIsFilled(NextUser);
	
EndFunction

Function NextUser(Document) Export
	
	If Document.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	DocumentsAcceptanceSliceLast.NextUser
	             |FROM
	             |	InformationRegister.DocumentsAcceptance.SliceLast(, Document = &Document) AS DocumentsAcceptanceSliceLast";
	
	Query.SetParameter("Document", Document);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.NextUser;
	Else
		Return Undefined;
	EndIf;
	
EndFunction
