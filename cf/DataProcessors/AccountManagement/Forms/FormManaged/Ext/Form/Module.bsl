#Region BaseFormsProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)   	

	RetStruct  =   DataProcessors.AccountManagement.PrintTemplate();
	SheetDoc.InsertArea(RetStruct.SpreadsheetDoc.Area());
	MapObjects = New FixedMap(RetStruct.MapObjects);
	
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)	 	
	
	ChoiceProcessingAtServer(SelectedValue);	

EndProcedure

&AtServer
Function  ChoiceProcessingAtServer(ChoiceValue)

	InfRegName 	  = ChoiceValue.MetadataName;
	InfRegDimName = Metadata["InformationRegisters"][InfRegName].Dimensions[0].Name;
	
	Obj = ChoiceValue.Ref;   
	
	RowObject 		= MapObjects.Get(Obj);
	InfRegSliceLast = InformationRegisters[InfRegName].SliceLast(, New Structure(InfRegDimName, Obj));
	
	If InfRegSliceLast.Count() = 1 Then
		
		InfRegLast = InfRegSliceLast[0];   		
		
		EditAreaPeriod 				  = SheetDoc.Area(RowObject, 4, RowObject, 4);
		EditAreaPeriod.Value 		  = InfRegLast.Period;
		EditAreaPeriod.Details.Period = InfRegLast.Period;
		
		Index = 0;
		
		For Each InfRegResource In Metadata["InformationRegisters"][InfRegName].Resources Do
			EditAreaResource				 =	SheetDoc.Area(RowObject, 5 + Index, RowObject, 5 + Index);
			EditAreaResource.Value			 = InfRegLast[EditAreaResource.Details.Cell];
			EditAreaResource.Details.Period  = InfRegLast.Period;
			
			Index = Index + 1;
		EndDo;  	
		
	EndIf; 

	        	
EndFunction

#EndRegion

#Region ItemsEvents

&AtClient
Procedure SpreadsheetDocumentSelection(Item, Area, StandardProcessing)
	
	StandardProcessing = False;

	If TypeOf(Area.Details) = Type("Structure") Then


		Obj = Undefined;
		If Area.Details.Property("Object", Obj) Then
			If IsFolder(Obj) Then
				StandardProcessing = False;
				Return;
			Else 
				If Area.Details.Property("OpenObjectForm") Then
					StandardProcessing = False;  					
					OpenCatalogForm(Obj); 					
					Return;
				EndIf;  
			EndIf;
		EndIf;
		
		ItsNew = False;
		If Area.Details.Property("ItsNew", ItsNew) Then
			If ItsNew Then
				
				Cell = "";
				StandardProcessing = True;
				
				If Area.Details.Property("Cell", Cell) Then
					If (Cell = "Period")Or(Cell = "RefObject") Then
						StandardProcessing = False;
						Return;
					Else

						Area.Protection = False; 
						
						CurrentDecipher = Area.Details;
						
						CurrentArea = Item.CurrentArea;
						ExtDimPosition = Find(Area.Details.Cell, "ExtDimension");
						If ExtDimPosition = 0 Then
						//	Area.ValueType = Area.Details.Register.Metadata.Resources[Area.Details.Cell].Type;
							Area.ValueType = GetValueType(Area.Details);
						Else
							NameCellAccout = Left(Area.Details.Cell, ExtDimPosition - 1);
							ValueAccountFound = "";
							NomberExtDimension = 0;
							//For index = 1 to Area.Details.Register.Metadata.Resources.Count() Do
							For index = 1 to Area.Details.Register.ResourcesCount Do

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
									StandardProcessing = False;
								EndIf;
							Else
								StandardProcessing = False;
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			Else
				
				OpenForm("CommonForm.BookkeepingSettingsCommonForm",New Structure("Ref, Period",Area.Details.Object,Area.Details.Period),ThisForm);
			EndIf;
			
		EndIf;
	EndIf;

EndProcedure    

&AtClient
Procedure SpreadsheetDocumentOnChangeAreaContent(Item, Area)
	
	If (Area.Left = Area.Right) And (Area.Top = Area.Bottom)And(TypeOf(Area.Details) = Type("Structure")) Then
		CurrentAreaName = Item.CurrentArea.Name;
		OnChangeValue(Area.Value);
	EndIf; 	
	
EndProcedure

&AtClient
Procedure SpreadsheetDocumentDetailProcessing(Item, Details, StandardProcessing)
	StandardProcessing = False; 
EndProcedure

#EndRegion

#Region OtherProceduresAndFunctions

&AtServerNoContext
Function IsFolder(Obj)
	
	Return   Obj.IsFolder;	
	
EndFunction

&AtServer
Function GetValueType(Details)
	
	Return  Metadata["InformationRegisters"][Details.Register.MetadataName].Resources[Details.Cell].Type; 

EndFunction

Procedure OnChangeValue(Value) Export 

	Area = SheetDoc.Area(CurrentAreaName);
	
	SelectReg = InformationRegisters[Area.Details.Register.MetadataName].Select(Area.Details.Period, Area.Details.Period, New Structure(Metadata["InformationRegisters"][Area.Details.Register.MetadataName].Dimensions[0].Name, Area.Details.Object));
	
	If SelectReg.Next() Then
		RecordManager = SelectReg.GetRecordManager();
	Else
		RecordManager = InformationRegisters[Area.Details.Register.MetadataName].CreateRecordManager();    		
	EndIf;
	RecordManager.Period = Date("19800101000000");
	RecordManager[Metadata["InformationRegisters"][Area.Details.Register.MetadataName].Dimensions[0].Name] = Area.Details.Object; 	
	RecordManager[Area.Details.Cell] = Value;
	
	ForDel = True;
	For Each Resource In Metadata["InformationRegisters"][Area.Details.Register.MetadataName].Resources Do
		If ValueIsFilled(RecordManager[Resource.Name]) Then
			ForDel = False;
			Break;
		EndIf;
	EndDo;
	
	EditArea 	= SheetDoc.Area(Area.Top,3,Area.Top, Area.Details.Register.ResourcesCount + 4);
	PeriodArea  = SheetDoc.Area(Area.Top,4,Area.Top, 4);
	If ForDel Then
		RecordManager.Delete();
		EditArea.BackColor = WebColors.White;
		PeriodArea.Value = "";
	Else
		RecordManager.Write();
		PeriodArea.Value = RecordManager.Period;
		EditArea.BackColor = WebColors.SeaShell;
	EndIf;
	
EndProcedure

&AtClient 
Procedure OpenCatalogForm(Obj)
	
	RefStruct  =  New Structure;
	RefStruct.Insert("Key",Obj);
	
	ObjFormName = GetCatalogTypeName(Obj);
	
	If ObjFormName <> "" Then
		
		OpenForm(ObjFormName,RefStruct);
		
	EndIf;
	
EndProcedure

&AtServer
Function GetCatalogTypeName(Ref)
	
	Return Ref.Metadata().FullName() + ".ObjectForm";
	
EndFunction

#EndRegion

