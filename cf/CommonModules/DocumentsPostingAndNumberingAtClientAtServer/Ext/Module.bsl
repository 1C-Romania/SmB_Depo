Function GetDocumentAutoNumberPresentation(Val DocumentObject) Export
	
	InitialCounter = "";
	
	Prefix = DocumentsPostingAndNumberingAtServer.GetDocumentNumberPrefix(DocumentObject, InitialCounter);
	
	StarStr = "";
	For x = 1 To StrLen(InitialCounter) Do
		StarStr = StarStr + "*";
	EndDo;
	
	Return Prefix + StarStr;
	
EndFunction

Function ReplacePrefixTokens_Date(Val Prefix, Date) Export
	
	YYYY = Format(Date, "DF=yyyy");
	YY   = Format(Date, "DF=yy");
	MM   = Format(Date, "DF=MM");
	
	Prefix = StrReplace(Prefix, "[YYYY]", YYYY);
	Prefix = StrReplace(Prefix, "[YY]", YY);
	Prefix = StrReplace(Prefix, "[MM]", MM);
	
	Return Prefix;
	
EndFunction

&AtClient
Procedure AllowNumberChangesQuery(Form) Export
	QueryText = NStr("en='ATTENTION! After changing the number automatic numbering for this document will be disabled!"
"Enable number editing?';pl='UWAGA! Po zmianie numeru numeracja automatyczna tego dokumentu zostanie wyłączona!"
"Włączyć moźliwość zmiany numeru?';ru='ВНИМАНИЕ! После изменения номера автоматическая нумерация документов будет отключена!"
"Разрешить редактирование номера документа?'");
	ShowQueryBox(New NotifyDescription("AllowNumberChangesAnswer", DocumentsPostingAndNumberingAtClientAtServer,New Structure("Form",Form)), QueryText, QuestionDialogMode.YesNo);	
EndProcedure

&AtClient
Procedure AllowNumberChangesAnswer(Answer, Parameters)  Export
	If Answer = DialogReturnCode.Yes Then
		Form = Parameters.Form;
		If Form.ShowNumberPreview Then
			Form.Object.Number = StrReplace(Form.NumberPreview,"*","");			
			Form.ShowNumberPreview = False;		
		EndIf;
		Form.Items.Number.TextEdit=True;
		Form.Items.Number.ChoiceButton=False;	
		Form.UpdateDialog();			
	EndIf;
EndProcedure
