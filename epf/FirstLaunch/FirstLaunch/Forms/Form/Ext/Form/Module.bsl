
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillCountries();
	FillChoiceList();
	
EndProcedure

&AtServer
Procedure FillCountries()
	
	// Fill countries from template
	Obj = FormAttributeToValue("Object");
	Template = Obj.GetTemplate("Countries");
	AreaCountries = Template.GetArea("Countries");
	Top = AreaCountries.Area().Top;
	Bottom = AreaCountries.Area().Bottom;
	
	For RowNumber = Top To Bottom Do
		
		StructureCountry = New Structure("Country, Description, Postfix");
		StructureCountry.Country = AreaCountries.Area(RowNumber, 1, RowNumber,1).Text;
		StructureCountry.Description = AreaCountries.Area(RowNumber, 2, RowNumber, 2).Text;
		StructureCountry.Postfix = AreaCountries.Area(RowNumber, 3, RowNumber, 3).Text;
		
		If ValueIsFilled(StructureCountry.Country) Then
			NewRow = Countries.Add();
			FillPropertyValues(NewRow, StructureCountry);
		EndIf
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillChoiceList()
	
	ArrayOfCountries = Countries.Unload().UnloadColumn("Country");
	Items.Country.ChoiceList.LoadValues(ArrayOfCountries);
	If Countries.Count() > 0 Then
		Object.Country = Countries[0].Country;
		Object.Descriprion = Countries[0].Description;
		Postfix = Countries[0].Postfix;
	EndIf;
	
EndProcedure

&AtClient
Procedure CountryOnChange(Item)
	
	Rows = Countries.FindRows(New Structure("Country", Object.Country));
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	Object.Descriprion = Rows[0].Description;
	Postfix = Rows[0].Postfix;
	
EndProcedure

&AtClient
Procedure TipOfChoiceCountryURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	ShowMessageBox(, NStr("ru='Здесь будет подсказка...'; en='This is tip...'"));
EndProcedure

&AtClient
Procedure Go(Command)
	
	FillPredefinedDataAtServer();
	
EndProcedure

&AtServer
Procedure FillPredefinedDataAtServer()
	
	Obj = FormAttributeToValue("Object");
	
	Structure = Obj.PredefinedDataAtServer(Postfix);
	If Structure.Property("Company") And Structure.Company.Property("DescriptionFull") Then
		DescriptionFull = Structure.Company.DescriptionFull;
		InformationAboutCompany = Structure.Company;
		InformationAboutCompany.Insert("DefaultVATRate", Structure.VAT);
	EndIf;
	
	AccountingCurrency = Structure.Currency;
	NationalCurrency   = Structure.Currency;
	
	// Set page "Company"
	Items.GroupPages.CurrentPage = Items.PageCompany;
	Items.Finish.DefaultButton = True;
	
EndProcedure

&AtClient
Procedure Finish(Command)
	
	FinishAtServer();
	Close(True);
	
EndProcedure

&AtServer
Procedure FinishAtServer()
	
	InformationAboutCompany.Insert("DescriptionFull", DescriptionFull);
	
	Structure = New Structure;
	Structure.Insert("Company",				InformationAboutCompany);
	Structure.Insert("AccountingCurrency", 	AccountingCurrency);
	Structure.Insert("NationalCurrency", 	NationalCurrency);
	
	Obj = FormAttributeToValue("Object");
	Obj.CreateCompany(Structure);
	
EndProcedure
