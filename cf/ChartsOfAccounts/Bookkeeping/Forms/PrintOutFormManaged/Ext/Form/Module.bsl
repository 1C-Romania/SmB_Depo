
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("YearValidity") Then
		YearValidity = Parameters.YearValidity;
	EndIf;
	Company = CommonAtServer.GetUserSettingsValue("Company");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	MarkAccountsInColor = True;
EndProcedure

&AtClient
Procedure CommandGenerate(Command)
	If Company.IsEmpty() Then
		ShowMessageBox( , NStr("en='Please, choose the company.';pl='Wypełnij firmę przed drukowaniem planu kont.';ru='Заполните поле ""Организация"" перед печатью плана счетов.'"));
		Return;
	EndIf;
	
	Spreadsheet = New SpreadsheetDocument;	
	CommandGenerateAtServer(Spreadsheet);
	
	PrintoutStructure = New Structure;
	PrintoutStructure.Insert("Description","Wydruk planu kont");
	PrintoutStructure.Insert("ObjectRef",Undefined);
	PrintoutStructure.Insert("PrintOut",Spreadsheet);
	PrintoutStructure.Insert("Messages",Undefined);
		
	PrintoutsArray = New Array;
	PrintoutsArray.Add(PrintoutStructure);
	
	PrintList = New Array;	
	// Jack 28.06.2017
	// to do
	//OpenForm("CommonForm.GeneralPrintoutFormManaged", New Structure("PrintList, DirectPrinting, PrintFileName, InitialFormID, SpreadsheetsFromOutside, PrintoutsArray", PrintList, False, "", ThisForm.UUID, True, PrintoutsArray ),,True);	
	
	Close();
	
EndProcedure

&AtServer
Procedure CommandGenerateAtServer(Spreadsheet)
	
	LanguageCode = Common.GetDefaultLanguageCodeAndDescription().LanguageCode;
	
	GenerationDate = CurrentDate(); // fixing generation time
	
	// Getting templates
	Template = ChartsOfAccounts.Bookkeeping.GetTemplate("PrintOutTemplate");
	Template.TemplateLanguageCode = LanguageCode;
	
	Header = Template.GetArea("Header");
	AccountHeader = Template.GetArea("AccountHeader");
	
	// Jack 25.06.2017
	// to do
	CompanyName = "";
	CompanyVATNumber = "";
	//CompanyVATNumber = Taxes.GetBusinessPartnerVATNumberDescription(CurrentDate(),Company,LanguageCode);
	//CompanyName      = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(CurrentDate(), New Structure("BusinessPartner, Attribute", Company, Enums.BusinessPartnersAttributesTypes.LongDescription)).Description;
	
	//CompanyAddressRecord = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(CurrentDate(), New Structure("BusinessPartner, Attribute", Company, Enums.BusinessPartnersAttributesTypes.LegalAddress));
	//
	//Header.Drawings.CompanyLogo.Picture = CommonAtServer.GetCompanyLogo(Company);
	//Header.Parameters.CompanyName      = CompanyName;
	//Header.Parameters.CompanyAddress   = CompanyAddressRecord.Description;
	//Header.Parameters.CompanyVATNumber = CompanyVATNumber;
	
	Header.Parameters.YearValidity = YearValidity;
	
	Spreadsheet.Put(Header);
	Spreadsheet.Put(AccountHeader);
	
	SpreadSheet.RepeatOnRowPrint = Spreadsheet.Area(Spreadsheet.TableHeight, , Spreadsheet.TableHeight);
	
	Query = New Query;			 
	Query.Text = "SELECT
	             |	Bookkeeping.Ref,
	             |	Bookkeeping.AdditionalView AS Code,
	             |	Bookkeeping.Description,
	             |	Bookkeeping.Parent,
	             |	Bookkeeping.BalanceType AS BalanceType,
	             |	REFPRESENTATION(Bookkeeping.BalanceType) AS BalanceTypePresentation,
	             |	Bookkeeping.Remarks,
	             |	Bookkeeping.Currency,
	             |	Bookkeeping.ExtDimensionTypes.(
	             |		LineNumber AS LineNumber,
	             |		ExtDimensionType.Presentation AS ExtDimensionType,
	             |		Mandatory,
	             |		TurnoversOnly
	             |	)
	             |FROM
	             |	ChartOfAccounts.Bookkeeping AS Bookkeeping
	             |WHERE
	             |	Bookkeeping.DeletionMark IN (&DeletionMarkTrue, &DeletionMarkFalse)
	             |	" + ?(ValueIsFilled(YearValidity),"AND (Bookkeeping.FinancialYearsBegin = VALUE(Catalog.FinancialYears.EmptyRef)
	             |			OR Bookkeeping.FinancialYearsBegin.DateFrom <= &DateEndYearValidity)
	             |	AND (Bookkeeping.FinancialYearsEnd =  VALUE(Catalog.FinancialYears.EmptyRef)
	             |			OR Bookkeeping.FinancialYearsEnd.DateTo >= &DateStartYearValidity)","") +"
	             |
	             |ORDER BY
	             |	Code,
	             |	LineNumber";
				 
	Query.SetParameter("DeletionMarkTrue", PrintDeletionMarked);
	Query.SetParameter("DeletionMarkFalse", False);
	If ValueIsFilled(YearValidity) Then
		Query.SetParameter("DateStartYearValidity", YearValidity.DateFrom);
		Query.SetParameter("DateEndYearValidity", YearValidity.DateTo);		
	EndIf;
	
	LineNumber = 0;
	ParentsStack = New Array;
	ParentsStack.Add(ChartsOfAccounts.Bookkeeping.EmptyRef());
	CurrentLevel = 0;
	RemarksIsPrinted = False;
	
	Spreadsheet.StartRowAutoGrouping();
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		LineNumber = LineNumber + 1;
		
		AccountRow = Template.GetArea("AccountRow");
		AccountRowRemarks = Template.GetArea("AccountRowRemarks");
		
		ParentsStackIndex = ParentsStack.Find(Selection.Parent);
		If ParentsStackIndex = Undefined Then // new parent, new level
			CurrentLevel = CurrentLevel + 1;
			ParentsStack.Add(Selection.Parent);
			Spreadsheet.Area(Spreadsheet.TableHeight - RemarksIsPrinted, 1, Spreadsheet.TableHeight, Spreadsheet.TableWidth).Font = New Font(Spreadsheet.Area(Spreadsheet.TableHeight, 2).Font, , , True);
		ElsIf ParentsStackIndex = ParentsStack.UBound() Then // current level
			// Nothing to do.
		Else
			CurrentLevel = ParentsStackIndex;
			While ParentsStack.UBound() > ParentsStackIndex Do
				ParentsStack.Delete(ParentsStack.UBound());
			EndDo;
		EndIf;
		AccountRow.Parameters.LineNumber = LineNumber;
		AccountRow.Parameters.Ref = Selection.Ref;
		AccountRow.Parameters.Code = Selection.Code;
		AccountRow.Parameters.Description = Selection.Description;
		AccountRow.Parameters.BalanceType = Selection.BalanceTypePresentation;
		AccountRow.Parameters.Currency = Format(Selection.Currency, "BF=; BT=+");
				
		ExtDimensionsSelection = Selection.ExtDimensionTypes.Select();
		While ExtDimensionsSelection.Next() Do
			
			ExtDimensionPresentation = ExtDimensionsSelection.ExtDimensionType;
			
			If Not ExtDimensionsSelection.Mandatory Or ExtDimensionsSelection.TurnoversOnly Then
				
				ExtDimensionPresentation = ExtDimensionPresentation + " (";
				
				If Not ExtDimensionsSelection.Mandatory Then
					ExtDimensionPresentation = ExtDimensionPresentation + NStr("en='not mandatory';pl='nie wymagana';ru='необязательная'", LanguageCode) + ", ";
				EndIf;
				
				If ExtDimensionsSelection.TurnoversOnly Then
					ExtDimensionPresentation = ExtDimensionPresentation + NStr("en='turnovers only';pl='tylko obroty';ru='только обороты'", LanguageCode) + ", ";
				EndIf;
				
				ExtDimensionPresentation = Left(ExtDimensionPresentation, StrLen(ExtDimensionPresentation) - 2);
				ExtDimensionPresentation = ExtDimensionPresentation + ")";
				
			EndIf;
			
			AccountRow.Parameters["ExtDimension" + ExtDimensionsSelection.LineNumber] = ExtDimensionPresentation;
			
		EndDo;
		
		Spreadsheet.Put(AccountRow, CurrentLevel);
		
		If PrintRemarks And Not IsBlankString(Selection.Remarks) Then
			
			AccountRowRemarks.Parameters.Ref = Selection.Ref;
			AccountRowRemarks.Parameters.Remarks = Selection.Remarks;
			
			Spreadsheet.Put(AccountRowRemarks, CurrentLevel);
			RemarksIsPrinted = True;
			
		Else
			
			RemarksIsPrinted = False;
			
		EndIf;
		
		Spreadsheet.Area(Spreadsheet.TableHeight, 1, Spreadsheet.TableHeight, 2).BottomBorder = New Line(SpreadsheetDocumentCellLineType.Dotted);
		
		If MarkAccountsInColor Then
			If Selection.BalanceType = Enums.AccountBalanceTypes.Result Then
				Spreadsheet.Area(Spreadsheet.TableHeight - RemarksIsPrinted, 1, Spreadsheet.TableHeight, Spreadsheet.TableWidth).BackColor = Webcolors.LightBlue;
			ElsIf Selection.BalanceType = Enums.AccountBalanceTypes.OffBalance Then
				Spreadsheet.Area(Spreadsheet.TableHeight - RemarksIsPrinted, 1, Spreadsheet.TableHeight, Spreadsheet.TableWidth).BackColor = Webcolors.LightYellow;
			EndIf;
		EndIf;
		
	EndDo;
	
	Spreadsheet.Area(Spreadsheet.TableHeight, 1, Spreadsheet.TableHeight, Spreadsheet.TableWidth).BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
	
	Spreadsheet.EndRowAutoGrouping();
	
	// Printing parameters.
	Spreadsheet.PageOrientation = PageOrientation.Landscape;
	Spreadsheet.FitToPage = True;
	
	// Header and footer values.
	Spreadsheet.Header.Enabled   = True;
	Spreadsheet.Footer.Enabled   = True;
	
	Spreadsheet.Header.LeftText  = Nstr("en='Company';pl='Firma';ru='Организация'", LanguageCode)+": " + CompanyName + " " + CompanyVATNumber;
	Spreadsheet.Header.RightText = Nstr("en='Chart of account';pl='Plan kont';ru='План счетов'", LanguageCode)+". " + Nstr("en='Generated';pl='Wygenerowany';ru='Сформированный'", LanguageCode)+": " + GenerationDate;
	
	Spreadsheet.Footer.LeftText  = CommonAtServer.GetGeneratedByText();
	Spreadsheet.Footer.RightText = NStr("en='Page [&PageNumber] from [&PagesTotal]';pl='Strona [&PageNumber] z [&PagesTotal]';ru='Страница [&PageNumber] из [&PagesTotal]'");
	
EndProcedure



