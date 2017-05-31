Procedure SetCommandsInterface(Form)
	If Not Form.Items.Find("FormCommonCommandEditObjectFiles") = Undefined Then
		Form.Items.FormCommonCommandEditObjectFiles.Visible = False;
	EndIf;
EndProcedure

Procedure ExpandedAllTree(CollectionElements, FormItem) Export 
	
	For Each CollectionElement In CollectionElements Do
		FormItem.Expand(CollectionElement.GetID());
		
		NestedItems = CollectionElement.GetItems();
		If (NestedItems.Count() > 0) Then
			ExpandedAllTree(NestedItems, FormItem);
		Else
			Continue;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CatalogListFormOnOpen(Form, Cancel) Export
	SetCommandsInterface(Form)
EndProcedure

Procedure BaseContactInformationOnChange(Form) Export
	For Each RowContactInformation In Form.BaseContactInformationList Do
		If Find(Form.CurrentItem.Name, "Contact_") > 0 Then
			ContactInformationProfile = Form["Profile" + Form.CurrentItem.Name];
		Else
			ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles." + Form.CurrentItem.Name);
		EndIf;
		
		If RowContactInformation.ContactInformationProfile = ContactInformationProfile Then
			If Form.HeaderAttributes.Property(Form.CurrentItem.Name) Then
				RowContactInformation.Description = Form.Object[Form.CurrentItem.Name];
			ElsIf Not Form.Items.Find(Form.CurrentItem.Name) = Undefined Then
				RowContactInformation.Description = Form[Form.CurrentItem.Name];
			EndIf;
		EndIf;
	EndDo;
	Form.Modified = True;
EndProcedure


Procedure PrepareHistoricalAttributesToWrite(Form, Cancel, WriteParameters)
	If Form.ObjectMetadataName = "Suppliers" Then
		ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles.SupplierLegalAddress");
	ElsIf Form.ObjectMetadataName = "Customers" Then
		ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles.CustomerLegalAddress");
	ElsIf Form.ObjectMetadataName = "Companies" Then
		ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles.CompanyLegalAddress");
	Else
		ContactInformationProfile = Undefined;
	EndIf;
	
	NewAttributesForChange = New Array;
	
	TempHistoricalAttributesToWrite = New Structure;
	Index = 1;
	
	For Each AttributesForChangeItem In Form.AttributesForChange Do
		If AttributesForChangeItem.FirstValue Then
			If AttributesForChangeItem.AttributeName = "LegalAddress" Then
				FindRows = Form.BaseContactInformationList.FindRows(New Structure("ContactInformationProfile", ContactInformationProfile));
				If FindRows.Count() = 0 Then
					Continue;
				EndIf;
				FindRow = FindRows[0];
				For i = 1 To 10 Do
					AttributesForChangeItem.NewStructureFields["Field" + Format(i,"NG=0")] = FindRow["Field" + Format(i,"NG=0")];
				EndDo;
				NewValue = FindRow.Description;
			Else
				NewValue = Form.Object[AttributesForChangeItem.AttributeName];
			EndIf;	
			TempHistoricalAttributesToWrite.Insert("Row"+Format(Index,"NG=0"),New Structure("Attribute, Period, Value, NewStructureFields",AttributesForChangeItem.Attribute,AttributesForChangeItem.NewAttributePeriod, NewValue, AttributesForChangeItem.NewStructureFields));
			Index = Index + 1;
		Else
			If AttributesForChangeItem.AttributeName = "LegalAddress" Then
				FindRows = Form.BaseContactInformationList.FindRows(New Structure("ContactInformationProfile", ContactInformationProfile));
				If FindRows.Count() = 0 Then
					Continue;
				EndIf;
				FindRow = FindRows[0];
				ForChange = False;
				If Not AttributesForChangeItem.CurrentAttributeValue = FindRow.Description Then
					AttributesForChangeItem.NewAttributeValue = FindRow.Description;
					ForChange = True;
				EndIf;
				For i = 1 To 10 Do
					If Not AttributesForChangeItem.CurrentStructureFields["Field" + Format(i,"NG=0")] = FindRow["Field" + Format(i,"NG=0")] Then
						AttributesForChangeItem.NewStructureFields["Field" + Format(i,"NG=0")] = FindRow["Field" + Format(i,"NG=0")];
						ForChange = True;
					EndIf;
				EndDo;
				If ForChange Then
					AttributesForChangeItem.NewAttributeValue = FindRow.Description;
					NewAttributesForChange.Add(AttributesForChangeItem);
				EndIf;
			ElsIf Not AttributesForChangeItem.CurrentAttributeValue = AttributesForChangeItem.NewAttributeValue Then
				If Not AttributesForChangeItem.CurrentAttributeValue = Form.Object[AttributesForChangeItem.AttributeName] Then
					AttributesForChangeItem.NewAttributeValue = Form.Object[AttributesForChangeItem.AttributeName];
					NewAttributesForChange.Add(AttributesForChangeItem);
				EndIf;
			EndIf;	
		EndIf;	
	EndDo;	
	
	//initial dialog window
	If NewAttributesForChange.Count() > 0 Then
		
		FormStructure = New Structure;
		FormStructure.Insert("AttributesForChange", NewAttributesForChange);
		DialogResponseStructure = OpenFormModal("CommonForm.DialogBusinessPartnersAttributesHistoryChangeManagedForm", FormStructure, Form);
		If DialogResponseStructure = Undefined Or DialogResponseStructure.DialogReturnCode <> DialogReturnCode.OK Then
			Cancel = True;
			Return;
		EndIf;	
		
		For Each AttributesForChangeItem In DialogResponseStructure.AttributesToChange Do
			
			TempHistoricalAttributesToWrite.Insert("Row"+Format(Index,"NG=0"),New Structure("Attribute, Period, Value, NewStructureFields", AttributesForChangeItem.Attribute, AttributesForChangeItem.NewAttributePeriod, AttributesForChangeItem.NewAttributeValue, New FixedStructure(AttributesForChangeItem.NewStructureFields)));
			Index = Index + 1;
			
		EndDo;	
		
	EndIf;
	
	Form.HistoricalAttributesToWrite = New FixedStructure(TempHistoricalAttributesToWrite);
EndProcedure

&AtClient
Procedure SaveCatalogItemWithHistoricalAttributes(Object, Form, IsHistoricalAttributesToWrite, CloseAfterWrite) Export  
	
	Form.Object.LongDescription = Form.Object.Description;
	If IsHistoricalAttributesToWrite Then 
		
		BeforeWriteHistoricalAttributes(Form, Object, CloseAfterWrite);
		
	Else

		WriteObjectWithHistoricalAttributes(Object, Form, CloseAfterWrite);		
		
	EndIf;
	
EndProcedure

Procedure BeforeWriteHistoricalAttributes(Form, Object, CloseAfterWrite) Export
	If Form.ObjectMetadataName = "Suppliers" Then
		ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles.SupplierLegalAddress");
	ElsIf Form.ObjectMetadataName = "Customers" Then
		ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles.CustomerLegalAddress");
	ElsIf Form.ObjectMetadataName = "Companies" Then
		ContactInformationProfile = PredefinedValue("Catalog.ContactInformationProfiles.CompanyLegalAddress");
	Else
		ContactInformationProfile = Undefined;
	EndIf;
	
	NewAttributesForChange = New Array;
	
	TempHistoricalAttributesToWrite = New Structure;
	Index = 1;
	
	For Each AttributesForChangeItem In Form.AttributesForChange Do
		If AttributesForChangeItem.FirstValue Then
			If AttributesForChangeItem.AttributeName = "LegalAddress" Then
				FindRows = Form.BaseContactInformationList.FindRows(New Structure("ContactInformationProfile", ContactInformationProfile));
				If FindRows.Count() = 0 Then
					Continue;
				EndIf;
				FindRow = FindRows[0];
				For i = 1 To 10 Do
					AttributesForChangeItem.NewStructureFields["Field" + Format(i,"NG=0")] = FindRow["Field" + Format(i,"NG=0")];
				EndDo;
				NewValue = FindRow.Description;
			Else
				If ValueIsFilled(AttributesForChangeItem.Country) Then
					VATNumbersRows = Form.VATNumbers.FindRows(New Structure("Country", AttributesForChangeItem.Country));
					If VATNumbersRows.Count() > 0 Then
						NewValue = VATNumbersRows[0].VATNumber;
						If ValueIsFilled(NewValue) Then
							AttributesForChangeItem.NewAttributeValue = NewValue;
							NewAttributesForChange.Add(AttributesForChangeItem);
						EndIf;
					EndIf;
				Else
					NewValue = Form.Object[AttributesForChangeItem.AttributeName];
				EndIf;
			EndIf;	
			TempHistoricalAttributesToWrite.Insert("Row"+Format(Index,"NG=0"),New Structure("Attribute, Period, Value, NewStructureFields, Country",AttributesForChangeItem.Attribute,AttributesForChangeItem.NewAttributePeriod, NewValue, AttributesForChangeItem.NewStructureFields, AttributesForChangeItem.Country));
			Index = Index + 1;
		Else
			If AttributesForChangeItem.AttributeName = "LegalAddress" Then
				FindRows = Form.BaseContactInformationList.FindRows(New Structure("ContactInformationProfile", ContactInformationProfile));
				If FindRows.Count() = 0 Then
					Continue;
				EndIf;
				FindRow = FindRows[0];
				ForChange = False;
				If Not AttributesForChangeItem.CurrentAttributeValue = FindRow.Description Then
					AttributesForChangeItem.NewAttributeValue = FindRow.Description;
					ForChange = True;
				EndIf;
				For i = 1 To 10 Do
					If Not AttributesForChangeItem.CurrentStructureFields["Field" + Format(i,"NG=0")] = FindRow["Field" + Format(i,"NG=0")] Then
						AttributesForChangeItem.NewStructureFields["Field" + Format(i,"NG=0")] = FindRow["Field" + Format(i,"NG=0")];
						ForChange = True;
					EndIf;
				EndDo;
				If ForChange Then
					AttributesForChangeItem.NewAttributeValue = FindRow.Description;
					NewAttributesForChange.Add(AttributesForChangeItem);
				EndIf;
			ElsIf Not AttributesForChangeItem.CurrentAttributeValue = AttributesForChangeItem.NewAttributeValue Then
				If Not AttributesForChangeItem.CurrentAttributeValue = Form.Object[AttributesForChangeItem.AttributeName] Then
					If ValueIsFilled(AttributesForChangeItem.Country) Then
						VATNumbersRows = Form.VATNumbers.FindRows(New Structure("Country", AttributesForChangeItem.Country));
						If VATNumbersRows.Count() > 0 Then
							If Not AttributesForChangeItem.CurrentAttributeValue = VATNumbersRows[0].VATNumber Then
								AttributesForChangeItem.NewAttributeValue = VATNumbersRows[0].VATNumber;
								NewAttributesForChange.Add(AttributesForChangeItem);
							EndIf;
						EndIf;
					Else
						AttributesForChangeItem.NewAttributeValue = Form.Object[AttributesForChangeItem.AttributeName];
						NewAttributesForChange.Add(AttributesForChangeItem);
					EndIf;
				EndIf;
			EndIf;	
		EndIf;	
	EndDo;
	
	If NewAttributesForChange.Count() > 0 Then
		
		FormStructure = New Structure;
		FormStructure.Insert("AttributesForChange", NewAttributesForChange);
		
		NotifyParams	= New Structure("Form, Object, TempHistoricalAttributesToWrite, Index, CloseAfterWrite", Form, Object, TempHistoricalAttributesToWrite, Index, CloseAfterWrite);
		NotifyDescr		= New NotifyDescription("BeforeWriteHistoricalAttributesResponse", FormsAtClient, NotifyParams);
		
		OpenForm("CommonForm.DialogBusinessPartnersAttributesHistoryChangeManagedForm", FormStructure, Form, , , , NotifyDescr);
		
	Else
		
		Form.HistoricalAttributesToWrite = New FixedStructure(TempHistoricalAttributesToWrite);
		
		WriteObjectWithHistoricalAttributes(Object, Form, CloseAfterWrite);	
		
	EndIf;
	
EndProcedure

Procedure WriteObjectWithHistoricalAttributes(Object, Form, CloseAfterWrite)
	
	Try

		Object.Write();
	
	Except
		
	EndTry;
	
	If ValueIsFilled(Object.Object.Ref) AND CloseAfterWrite Then 
		
		Form.Close();
		
	EndIf;
	
EndProcedure

Procedure BeforeWriteHistoricalAttributesResponse(Answer, Parameters) Export 
	DialogResponseStructure	= Answer;
	Index	= Parameters.Index;
	TempHistoricalAttributesToWrite	= Parameters.TempHistoricalAttributesToWrite;
	
	If DialogResponseStructure = Undefined Or DialogResponseStructure.DialogReturnCode <> DialogReturnCode.OK Then
		Return;
	EndIf;	
	
	For Each AttributesForChangeItem In DialogResponseStructure.AttributesToChange Do
		
		TempHistoricalAttributesToWrite.Insert("Row"+Format(Index,"NG=0"),New Structure("Attribute, Period, Value, NewStructureFields", AttributesForChangeItem.Attribute, AttributesForChangeItem.NewAttributePeriod, AttributesForChangeItem.NewAttributeValue, New FixedStructure(AttributesForChangeItem.NewStructureFields)));
		Index = Index + 1;
		
	EndDo;
	
	Parameters.Form.HistoricalAttributesToWrite = New FixedStructure(TempHistoricalAttributesToWrite);
	
	WriteObjectWithHistoricalAttributes(Parameters.Object, Parameters.Form, Parameters.CloseAfterWrite);	

EndProcedure

Procedure BeforeWrite(Form, Cancel, WriteParameters) Export
	If Form.FormInformation.IsHistoricalAttributesToWrite Then
		PrepareHistoricalAttributesToWrite(Form, Cancel, WriteParameters);
	EndIf;
EndProcedure
