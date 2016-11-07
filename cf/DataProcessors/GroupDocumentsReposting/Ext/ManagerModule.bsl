#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure RepostingDocuments(ParametersStructure, StorageAddress) Export
	
	Query = New Query;
	Query.SetParameter("BeginOfPeriod", ?(ParametersStructure.BeginOfPeriod = Undefined, '00010101', BegOfDay(ParametersStructure.BeginOfPeriod)));
	If ValueIsFilled(ParametersStructure.EndOfPeriod) Then
		Query.SetParameter("EndOfPeriod", EndOfDay(ParametersStructure.EndOfPeriod));
	EndIf;
	Query.SetParameter("Company", ParametersStructure.Company);
	
	ErrorList = New ValueTable;
	ErrorList.Columns.Add("Text");
	ErrorList.Columns.Add("Ref");
	
	ReturnParameters = New Structure("DocumnetsPosted, FailedToPost", 0, 0);
	
	Query.Text = GetTextOfQueryByPrimaryDocuments();
	
	// Set filter by company
	TextOfConditionOfCompanies = ?(ValueIsFilled(ParametersStructure.Company), "And Journal.company IN (&Company)", "");
	Query.Text = StrReplace(Query.Text, "And &CompanyCondition", TextOfConditionOfCompanies);
	
	// Set filter by period
	If ValueIsFilled(ParametersStructure.EndOfPeriod) Then
		ConditionTextPeriod = ?(ValueIsFilled(ParametersStructure.BeginOfPeriod), "And Journal.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod", " And Journal.Date <= &EndOfPeriod");
	ElsIf ValueIsFilled(ParametersStructure.BeginOfPeriod) Then
		ConditionTextPeriod = " And Journal.Date >= &BeginOfPeriod";
	Else
		ConditionTextPeriod = "";
	EndIf; 
	Query.Text = StrReplace(Query.Text, "And &PeriodCondition", ConditionTextPeriod);
	Query.Text = Query.Text + "
		|ORDER
		|	BY Date, Ref";
	
	AllDocuments = Query.Execute().Unload();
	
	RowIndexBeginningDate	= Undefined;
	CurrentDateOf	= Undefined;
	TotalDocuments			= AllDocuments.Count();
	
	For IndexOf = 0 To TotalDocuments - 1 Do
		
		DocumentRow = AllDocuments[IndexOf];
		
		DocumentObject = DocumentRow.Ref.GetObject();
		
		If CurrentDateOf <> DocumentObject.Date Then
			RowIndexBeginningDate = IndexOf;
			CurrentDateOf  = DocumentObject.Date;
		EndIf;
		
		Try
			
			If DocumentObject.CheckFilling() Then
				
				DocumentObject.Write(DocumentWriteMode.Posting, DocumentPostingMode.Regular);
				ReturnParameters.DocumnetsPosted = ReturnParameters.DocumnetsPosted + 1;
				
			EndIf;
			
		Except
			
			ErrorInfo = ErrorInfo();
			
			MessageText = NStr("en='Document %1 is not posted! %2 Due to: %3';ru='Документ %1 не проведен! %2 По причине: %3'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText,
						String(DocumentObject), Chars.LF, ErrorDescription());
						
			AddErrorMessage(ErrorList, MessageText, DocumentObject);
			
			ReturnParameters.FailedToPost = ReturnParameters.FailedToPost + 1;
			
			If ParametersStructure.StopOnError Then
				
				Break;
				
			EndIf;
			
		EndTry;
		
	EndDo;
	
	If ErrorList.Count() > 0 Then
		
		ShowErrors(ErrorList);
		
	EndIf;
	
	PutToTempStorage(ReturnParameters, StorageAddress);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddErrorMessage(ErrorList, MessageText, ErrorObject)

	ErrorString = ErrorList.Add();
	ErrorString.Text  = MessageText;
	ErrorString.Ref = ErrorObject;

EndProcedure

Procedure ShowErrors(ErrorList)
	
	// A large error quantity when work in WEB mode lead to
	// platform error by this reason decision is received to limit the output message quantity with 50 number
	
	LimitOutputMessages = 50;
	
	For Each ErrorString IN ErrorList Do
		
		CommonUseClientServer.MessageToUser(
			ErrorString.Text, 
			ErrorString.Ref,
			"Date", 
			"Object"
		);
		
		LimitOutputMessages = LimitOutputMessages - 1;
		
		If LimitOutputMessages = 0 Then
			
			MessageText = NStr("en='%1 errors were found while reposting. 
		|First 50 error messages are provided for review. 
		|It is necessary to fix the specified errors and after that to repost the documents.';ru='При перепроведении выявлено %1 ошибок. 
		|Сообщения о первых 50 ошибках предоставлены к ознакомлению. 
		|Необходимо исправить указанные ошибки, после чего принять решение о повторном перепроведении документов.'");
			
			StringFunctionsClientServer.PlaceParametersIntoString(ErrorString, ErrorList.Count());
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			Break;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetTextOfQueryByPrimaryDocuments()

	QueryText = "";
	
	For Each DocumentMetadata IN Metadata.Documents Do
		
		// Some roles do not have rights to some documents
		If Not IsInRole("FullRights") Then
			If Not AccessRight("Read", DocumentMetadata) Then
				Continue;
			EndIf;
		EndIf;
		
		//Delete the documents which shouldn't be reposted
		If DocumentMetadata.Posting = Metadata.ObjectProperties.Posting.Allow Then
			QueryText = QueryText + ?(QueryText = "", "SELECT ALLOWED", "
				|
				|UNION ALL
				|
				|SELECT") + " 
				|	Date AS Date,
				|	""" + DocumentMetadata.Name + """ AS DocumentName, """ + DocumentMetadata.Synonym + """ AS DocumentSynonym, 
				|	Journal.Ref AS Ref, 
				|	NULL,
				|	NULL,
				|	NULL,
				|	FALSE AS Executed,
				|	Journal.Presentation AS Presentation,
				|	FALSE AS WasError
				|FROM Document." + DocumentMetadata.Name + " AS Journal
				|WHERE Posted
				|And &PeriodCondition
				|And &CompanyCondition
				|";

		EndIf;
	
	EndDo;

	Return QueryText;
	
EndFunction

#EndRegion

#EndIf