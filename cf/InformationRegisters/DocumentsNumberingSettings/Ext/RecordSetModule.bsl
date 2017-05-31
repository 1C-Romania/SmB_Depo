
Procedure BeforeWrite(Cancel, Replacing)
	
	If Not DataExchange.Load Then
		
		For each Record In ThisObject Do
			
			DocumentPrefixLen = StrLen(TrimAll(DocumentsPostingAndNumberingAtClientAtServer.ReplacePrefixTokens_Date(Record.Prefix, CurrentDate())));
			CounterLen = StrLen(TrimAll(Record.InitialCounter));
			
			If Record.DocumentType = Undefined Then
				Record.DocumentType = ThisObject.Filter.DocumentType.Value;
			EndIf;
			DocumentTypeMetadata = Record.DocumentType.Metadata();
			
			
			CompanyPrefixLen = 0;
			If CommonAtServer.IsDocumentAttribute("Company", DocumentTypeMetadata) Then
				
				Query = New Query;
				Query.Text = "SELECT
				|	Companies.Prefix
				|FROM
				|	Catalog.Companies AS Companies";
				
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					If StrLen(TrimAll(Selection.Prefix)) > CompanyPrefixLen Then
						CompanyPrefixLen = StrLen(TrimAll(Selection.Prefix));
					EndIf;
				EndDo;
				
			EndIf;
			
			DocumentCopyPrefixLen = 0;
			If SessionParameters.IsBookkeepingAvailable AND TypeOf(Record.DocumentType) = Type("DocumentRef.BookkeepingOperation") Then
				
				Query = New Query;
				Query.Text = "SELECT
				|	PartialBookkeepingJournals.Prefix
				|FROM
				|	Catalog.PartialBookkeepingJournals AS PartialBookkeepingJournals";
				
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					If StrLen(TrimAll(Selection.Prefix)) > DocumentCopyPrefixLen Then
						DocumentCopyPrefixLen = StrLen(TrimAll(Selection.Prefix));
					EndIf;
				EndDo;
				
			EndIf;
			
			TotalLen = CompanyPrefixLen + DocumentPrefixLen + DocumentCopyPrefixLen + CounterLen;
			
			If TotalLen > DocumentTypeMetadata.NumberLength Then
				Alerts.AddAlert(Alerts.ParametrizeString(NStr("en='Total length of created number (%P1) can exceed max number length for this type of documents (%P2). Reduce length of prefix or counter.';pl='Łączna długość stworzonego numeru (%P1) może przekraczać maksymalną długość numeru dokumentów wybranego  typu (%P2). Zmniejsz długość prefiksu lub licznika.';ru='Общая длина формируемого номера (P1%) превышает максимально допустимую длину номера (% P2) для документов выбранного типа. Сократите длину префикса или нумератора.'"), New Structure("P1, P2", TotalLen, DocumentTypeMetadata.NumberLength)), Enums.AlertType.Error, Cancel);
			EndIf;
			
			
			If Record.DocumentType = Undefined Then
				Common.ErrorMessage(NStr("en='Please, input document!';pl='Wprowadź dokument!';ru='Укажите тип документа!'"), Cancel);
			EndIf;
			
			If IsBlankString(Record.InitialCounter) Then
				Common.ErrorMessage(NStr("en='Please, input initial counter!';pl='Wprowadź licznik początkowy!';ru='Укажите начальный номер нумерации!'"), Cancel);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // BeforeWrite()
