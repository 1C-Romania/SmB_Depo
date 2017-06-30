
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(Object, Parameters, "Account, Date");
	
	If ValueIsNotFilled(Object.Date) Then
		Object.Date = CurrentDate();
	EndIf;
	
	ShowSpreadsheet();
EndProcedure

&AtClient
Procedure SpreadsheetDocumentSelection(Item, Area, StandardProcessing)
	StandardProcessing = False;
	
	DecipherFormName = "";
	DesipherFormParameters = New Structure;
	ResultOK = True;
	Try
		SpreadsheetDocumentSelectionAtServer(DecipherFormName, DesipherFormParameters, StandardProcessing, ResultOK);
		If ResultOK Then
			ShowValue(,DesipherFormParameters.Key);

		EndIf;
	Except
	
	EndTry;
	
EndProcedure

&AtServer
Procedure SpreadsheetDocumentSelectionAtServer(DecipherFormName, DesipherFormParameters, StandardProcessing, ResultOK)
	Area = Items.SpreadsheetDocument.GetSelectedAreas()[0];
		
	If Area.Details=Undefined Then
		ResultOK = False;		
		Return;
	EndIf;
	
	If TypeOf(Area.Details.Register) = Type("String") Then
		Area.Details.Register = GetFromTempStorage(Area.Details.Register);
	EndIf;
	If TypeOf(Area.Details.Object) = Type("String") Then
		Area.Details.Object = GetFromTempStorage(Area.Details.Object);		
	EndIf;
	
	
	If TypeOf(Area.Details) = Type("Structure") Then
		If Area.Details.Register.MetadataObject = Metadata.Catalogs.BookkeepingOperationsTemplates Then
			DecipherFormName = Metadata.FindByType(TypeOf(Area.Details.Object)).FullName() + ".ObjectForm";
			DesipherFormParameters.Insert("Key", Area.Details.Object); 
			Return;
		EndIf;
		DataObject = Undefined;
		If Area.Details.Property("Object", DataObject) Then
			If Metadata.Documents.Find(DataObject.Metadata().Name) = Undefined Then
				If DataObject.IsFolder Then
					Return;
				EndIf;
			Else
				DecipherFormName = Metadata.FindByType(TypeOf(DataObject)).FullName() + ".ObjectForm";
				DesipherFormParameters.Insert("Key", DataObject);
				Return;
			EndIf;
		EndIf;
		
		ItsNew = False;
		If Area.Details.Property("ItsNew", ItsNew) Then
			If ItsNew Then
				
				Cell = "";
				
				If Area.Details.Property("Cell", Cell) Then
					If (Cell = "Period") Or (Cell = "RefObject") Then
						Return;
					Else

						Area.Protection = False; 
						
						CurrentDecipher = Area.Details;
						
						CurrentArea = Items.SpreadsheetDocument.CurrentArea;
						ExtDimPosition = Find(Area.Details.Cell, "ExtDimension");
						If ExtDimPosition = 0 Then
							Area.ValueType = Area.Details.Register.Metadata.Resources[Area.Details.Cell].Type;
						Else
							NameCellAccout = Left(Area.Details.Cell, ExtDimPosition - 1);
							ValueAccountFound = "";
							NomberExtDimension = 0;
							For index = 1 to Area.Details.Register.Metadata.Resources.Count() Do
								CellTablDoc = Items.SpreadsheetDocument.Area(Area.Top, Index + 4, Area.Top, Index + 4);
								If TypeOf(CellTablDoc.Details) = Type("Structure") Then
									CellAccount = "";
									If CellTablDoc.Details.Property("Cell", CellAccount) Then
										If CellAccount = NameCellAccout Then
											ValueAccountFound = Items.SpreadsheetDocument.Area(Area.Top, Index + 4, Area.Top, Index + 4).Value;
											Break;
										EndIf;
									EndIf;
								EndIf;
							EndDo;
							If ValueIsFilled(ValueAccountFound) Then
								NomberExtDimension = StrReplace(Area.Details.Cell,NameCellAccout + "ExtDimension","");
								If ValueAccountFound["ExtDimension" + NomberExtDimension + "Mandatory"] Then
									Area.ValueType = ValueAccountFound["ExtDimension" + NomberExtDimension + "Type"].ValueType;
								Else

								EndIf;
							Else
								
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			Else
				SelectReg = InformationRegisters[Area.Details.Register.Metadata.Name].Select(Area.Details.Period, Area.Details.Period, New Structure(Area.Details.Register.Metadata.Dimensions[0].Name, Area.Details.Object));
				If SelectReg.Next() Then
					DecipherFormName = Area.Details.Register.MetadataObject.DefaultObjectForm.Name;
					DesipherFormParameters.Insert("IsOpeningViaCatalog", True);
					DesipherFormParameters.Insert("CloseOnChoice", False);
					
					KeyValues = New Structure("Period, " + Area.Details.Register.Metadata.Dimensions[0].Name, Area.Details.Period, Area.Details.Object);
					InfoRegisterRecordKey = InformationRegisters[Area.Details.Register.Metadata.Name].CreateRecordKey(KeyValues); 
					DesipherFormParameters.Insert("Key", InfoRegisterRecordKey);					
				EndIf;
			EndIf;
		EndIf;
	EndIf;	
EndProcedure

&AtClient
Procedure SpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	ShowSpreadsheet();
EndProcedure

&AtClient
Procedure AccountOnChange(Item)
	ShowSpreadsheet();
EndProcedure

&AtServer
Procedure ShowSpreadsheet()
	SpreadsheetDocument.Clear();
	
	If ValueIsFilled(Object.Account) Then
		DataProcessorObject = FormDataToValue(Object, Type("DataProcessorObject.AnalyzesUsingAccount"));
		PrintTemplateArea = DataProcessorObject.PrintTemplate().Area();
		
		ValueToFormData(DataProcessorObject, Object);
		
		SpreadsheetDocument.InsertArea(PrintTemplateArea);
	EndIf;
EndProcedure

