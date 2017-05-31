
#If ThickClientOrdinaryApplication Then
Procedure GenerateReport() Export
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If Not Document.Posted Then
		Message(NStr("en='Post document before report generation';pl='Zaksięguj dokument przed generowaniem raportu';ru='Проведите документ перед формированием отчета'"));
		Return;
	EndIf;
	
	SpreadsheetDoc = New SpreadsheetDocument;
	
	Template = GetTemplate("Template");
	HeaderArea = Template.GetArea("Header");
	HeaderArea.Parameters.DocumentPresentation = NStr("en='Documents records:';pl='Zapisy księgowe dokumentu:';ru='Бухгалтерские проводки документа:'") + " " + Document.Metadata().Synonym;
	HeaderArea.Parameters.Number = Document.Number;
	HeaderArea.Parameters.Date   = Document.Date;
	HeaderArea.Parameters.DocumentBase   = Document.DocumentBase;
	SpreadsheetDoc.Put(HeaderArea);
	
	SpreadsheetDoc.RepeatOnRowPrint = SpreadsheetDoc.Area(SpreadsheetDoc.TableHeight - 3, , SpreadsheetDoc.TableHeight);
	
	BookkeepingIsRegisterRecords = FALSE;
	
	MetadataDocument = Metadata.Documents[Document.Metadata().Name];
	
	
	For each RegisterRecords in MetadataDocument.RegisterRecords do
		If Metadata.AccountingRegisters.Bookkeeping = RegisterRecords Then
			BookkeepingIsRegisterRecords = TRUE;
			Break;
		EndIf;

	EndDo;

	Query = New Query;
	Query.Text = "SELECT ALLOWED 
	             |	BookkeepingRecordsWithExtDimensions.RecordType,
	             |	BookkeepingRecordsWithExtDimensions.LineNumber AS LineNumber,
	             |	BookkeepingRecordsWithExtDimensions.Account,
	    		 |	BookkeepingRecordsWithExtDimensions.Account.AdditionalView AS AccountAdditionalView,				 
				 |	BookkeepingRecordsWithExtDimensions.Company,
	             |	BookkeepingRecordsWithExtDimensions.ExtDimension1,
	             |	BookkeepingRecordsWithExtDimensions.ExtDimension2,
	             |	BookkeepingRecordsWithExtDimensions.ExtDimension3,
	             |	BookkeepingRecordsWithExtDimensions.Quantity,
	             |	BookkeepingRecordsWithExtDimensions.Currency,
	             |	BookkeepingRecordsWithExtDimensions.CurrencyAmount,
	             |	BookkeepingRecordsWithExtDimensions.AmountDr,
	             |	BookkeepingRecordsWithExtDimensions.AmountCr,
	             |	BookkeepingRecordsWithExtDimensions.Description,
	             |	BookkeepingRecordsWithExtDimensions.Period AS Date";	
	
	
	// If base document is BO
	If TypeOf(Document.Ref) = TypeOf(Documents.BookkeepingOperation.EmptyRef()) or BookkeepingIsRegisterRecords = TRUE   Then
		Query.Text = Query.Text + "	             		
				 |FROM
	             |	AccountingRegister.Bookkeeping.RecordsWithExtDimensions(, , Recorder = &ReportsDocument) AS BookkeepingRecordsWithExtDimensions
	             |
	             |ORDER BY
	             |	LineNumber";
		
	ElsIf BookkeepingIsRegisterRecords = FALSE Then
		Query.Text = Query.Text + "	             
				 |FROM
	             |	AccountingRegister.Bookkeeping.RecordsWithExtDimensions(, , ) AS BookkeepingRecordsWithExtDimensions
	             |		INNER JOIN InformationRegister.BookkeepingPostedDocuments AS BookkeepingPostedDocuments
	             |		ON BookkeepingRecordsWithExtDimensions.Recorder = BookkeepingPostedDocuments.BookkeepingOperation
	             |WHERE
	             |	BookkeepingPostedDocuments.Document = &ReportsDocument
	             |
	             |ORDER BY
	             |	LineNumber";

	EndIf;
	
	Query.SetParameter("ReportsDocument",Document);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	TotalDr = 0;
	TotalCr = 0;
	
	While Selection.Next() Do
		
		If Selection.RecordType = AccountingRecordType.Credit Then
			TypeColumn = Template.GetArea("CreditRow | TypeColumn");
			TotalCr = TotalCr + Selection.AmountCr;
		ElsIf Selection.RecordType = AccountingRecordType.Debit Then	
			TypeColumn = Template.GetArea("DebitRow | TypeColumn");	
			TotalDr = TotalDr + Selection.AmountDr;
		EndIf;
		
		SpreadsheetDoc.Put(TypeColumn);
		GeneralRow = Template.GetArea("GeneralRow | MainColumns");
		GeneralRow.Parameters.Fill(Selection);
		GeneralRow.Parameters.AmountDr = FormatAmount(Selection.AmountDr,NationalCurrency, "' '",,False);
		GeneralRow.Parameters.AmountCr = FormatAmount(Selection.AmountCr,NationalCurrency, "' '",,False);
		GeneralRow.Parameters.CurrencyAmount = FormatAmount(Selection.CurrencyAmount,Selection.Currency, " ",,False);
		
		SpreadsheetDoc.Join(GeneralRow);
		
	EndDo;
	
	SpreadsheetDoc.Area(SpreadsheetDoc.TableHeight, , SpreadsheetDoc.TableHeight).StayWithNext = True;
	
	FooterArea = Template.GetArea("Footer");
	FooterArea.Parameters.TotalDr = FormatAmount(TotalDr,NationalCurrency,,,False);
	FooterArea.Parameters.TotalCr = FormatAmount(TotalCr,NationalCurrency,,,False);
	SpreadsheetDoc.Put(FooterArea);
	
	SpreadsheetDoc.Header.Enabled   = True;
	SpreadsheetDoc.Header.LeftText  = ?(Document.Company.LongDescription = "", Document.Company.Description, Document.Company.LongDescription);
	
	SpreadsheetDoc.Footer.Enabled   = True;
	SpreadsheetDoc.Footer.LeftText  = NStr("en=""Generated by 1C:Enterprise 8.""; pl=""Wygenerowany przez 1C:Enterprise 8.""; ru=""Сформированный в 1C:Enterprise 8.""") + " " + Metadata.DetailedInformation;
	SpreadsheetDoc.Footer.RightText = NStr("en='Page [&PageNumber] from [&PagesTotal]';pl='Strona [&PageNumber] z [&PagesTotal]';ru='Страница [&PageNumber] из [&PagesTotal]'");
	
	GeneralPrintoutForm = Printouts.GetGeneralPrintoutForm(Document);
	If GeneralPrintoutForm.IsOpen() Then
		GeneralPrintoutForm.Controls.ReportsPanel.Pages.Delete(1);
	EndIf;	

	
	Printouts.PrintSpreadsheet(SpreadsheetDoc,GeneralPrintoutForm, Enums.PrintMode.Form, ThisObject.Metadata().Synonym);
	GeneralPrintoutForm.Open();
	
	
EndProcedure
#EndIf

Function Print() Export
	
	SpreadsheetDoc = New SpreadsheetDocument;
	
	NationalCurrency = DefaultValuesAtServer.GetNationalCurrency();
	
	If ObjectRef.IsEmpty() Then
		Message(NStr("en='Post document before report generation';pl='Zaksięguj dokument przed generowaniem raportu';ru='Проведите документ перед формированием отчета'"));
		Return SpreadsheetDoc;
	EndIf;
	
	Template = GetTemplate("Template");
	HeaderArea = Template.GetArea("Header");
	HeaderArea.Parameters.DocumentPresentation = NStr("en='Documents records:';pl='Zapisy księgowe dokumentu:';ru='Бухгалтерские проводки документа:'") + " " + ObjectRef.Metadata().Synonym;
	HeaderArea.Parameters.Number = ObjectRef.Number;
	HeaderArea.Parameters.Date   = ObjectRef.Date;
	Try
		HeaderArea.Parameters.DocumentBase   = ObjectRef.DocumentBase;	
	Except
	
	EndTry;

	SpreadsheetDoc.Put(HeaderArea);
	
	SpreadsheetDoc.RepeatOnRowPrint = SpreadsheetDoc.Area(SpreadsheetDoc.TableHeight - 3, , SpreadsheetDoc.TableHeight);
	
	BookkeepingIsRegisterRecords = FALSE;
	
	MetadataDocument = Metadata.Documents[ObjectRef.Metadata().Name];
	
	
	For each RegisterRecords in MetadataDocument.RegisterRecords do
		If Metadata.AccountingRegisters.Bookkeeping = RegisterRecords Then
			BookkeepingIsRegisterRecords = TRUE;
			Break;
		EndIf;

	EndDo;

	Query = New Query;
	Query.Text = "SELECT ALLOWED 
	             |	BookkeepingRecordsWithExtDimensions.RecordType,
	             |	BookkeepingRecordsWithExtDimensions.LineNumber AS LineNumber,
	             |	BookkeepingRecordsWithExtDimensions.Account,
	             |	BookkeepingRecordsWithExtDimensions.Account.AdditionalView AS AccountAdditionalView,				 
	             |	BookkeepingRecordsWithExtDimensions.Company,
	             |	BookkeepingRecordsWithExtDimensions.ExtDimension1,
	             |	BookkeepingRecordsWithExtDimensions.ExtDimension2,
	             |	BookkeepingRecordsWithExtDimensions.ExtDimension3,
	             |	BookkeepingRecordsWithExtDimensions.Quantity,
	             |	BookkeepingRecordsWithExtDimensions.Currency,
	             |	BookkeepingRecordsWithExtDimensions.CurrencyAmount,
	             |	BookkeepingRecordsWithExtDimensions.AmountDr,
	             |	BookkeepingRecordsWithExtDimensions.AmountCr,
	             |	BookkeepingRecordsWithExtDimensions.Description,
	             |	BookkeepingRecordsWithExtDimensions.Period AS Date";	
	
	
	// If base document is BO
	If TypeOf(ObjectRef.Ref) = TypeOf(Documents.BookkeepingOperation.EmptyRef()) or BookkeepingIsRegisterRecords = TRUE   Then
		Query.Text = Query.Text + "	             		
				 |FROM
	             |	AccountingRegister.Bookkeeping.RecordsWithExtDimensions(, , Recorder = &ReportsDocument) AS BookkeepingRecordsWithExtDimensions
	             |
	             |ORDER BY
	             |	LineNumber";
		
	ElsIf BookkeepingIsRegisterRecords = FALSE Then
		Query.Text = Query.Text + "	             
				 |FROM
	             |	AccountingRegister.Bookkeeping.RecordsWithExtDimensions(, , ) AS BookkeepingRecordsWithExtDimensions
	             |		INNER JOIN InformationRegister.BookkeepingPostedDocuments AS BookkeepingPostedDocuments
	             |		ON BookkeepingRecordsWithExtDimensions.Recorder = BookkeepingPostedDocuments.BookkeepingOperation
	             |WHERE
	             |	BookkeepingPostedDocuments.Document = &ReportsDocument
	             |
	             |ORDER BY
	             |	LineNumber";

	EndIf;
	
	Query.SetParameter("ReportsDocument",ObjectRef);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	TotalDr = 0;
	TotalCr = 0;
	
	While Selection.Next() Do
		
		If Selection.RecordType = AccountingRecordType.Credit Then
			TypeColumn = Template.GetArea("CreditRow | TypeColumn");
			TotalCr = TotalCr + Selection.AmountCr;
		ElsIf Selection.RecordType = AccountingRecordType.Debit Then	
			TypeColumn = Template.GetArea("DebitRow | TypeColumn");	
			TotalDr = TotalDr + Selection.AmountDr;
		EndIf;
		
		SpreadsheetDoc.Put(TypeColumn);
		GeneralRow = Template.GetArea("GeneralRow | MainColumns");
		GeneralRow.Parameters.Fill(Selection);
		
		GeneralRow.Parameters.AmountDr = FormatAmount(Selection.AmountDr,NationalCurrency, "' '",,False);
		GeneralRow.Parameters.AmountCr = FormatAmount(Selection.AmountCr,NationalCurrency, "' '",,False);
		GeneralRow.Parameters.CurrencyAmount = FormatAmount(Selection.CurrencyAmount,Selection.Currency, " ",,False);
		
		SpreadsheetDoc.Join(GeneralRow);
		
	EndDo;
	
	SpreadsheetDoc.Area(SpreadsheetDoc.TableHeight, , SpreadsheetDoc.TableHeight).StayWithNext = True;
	
	FooterArea = Template.GetArea("Footer");
	FooterArea.Parameters.TotalDr = FormatAmount(TotalDr,NationalCurrency,,,False);
	FooterArea.Parameters.TotalCr = FormatAmount(TotalCr,NationalCurrency,,,False);
	SpreadsheetDoc.Put(FooterArea);
	
	SpreadsheetDoc.Header.Enabled   = True;
	SpreadsheetDoc.Header.LeftText  = ?(ObjectRef.Company.LongDescription = "", ObjectRef.Company.Description, ObjectRef.Company.LongDescription);
	
	SpreadsheetDoc.Footer.Enabled   = True;
	SpreadsheetDoc.Footer.LeftText  = NStr("en=""Generated by 1C:Enterprise 8.""; pl=""Wygenerowany przez 1C:Enterprise 8.""") + " " + Metadata.DetailedInformation;
	SpreadsheetDoc.Footer.RightText = NStr("en='Page [&PageNumber] from [&PagesTotal]';pl='Strona [&PageNumber] z [&PagesTotal]';ru='Страница [&PageNumber] из [&PagesTotal]'");
		
	Return SpreadsheetDoc;
	
EndFunction

