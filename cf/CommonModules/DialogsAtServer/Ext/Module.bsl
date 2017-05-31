Procedure CheckAccountsExtDimensions(Account, ExtDimensionName = "ExtDimension", Object) Export 
	
	MaxExtraDimension = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	
	//??? reset values
	If Not ValueIsFilled(Account) Then
		ExtDimension1 = Undefined;
		ExtDimension2 = Undefined;
		ExtDimension3 = Undefined;
	EndIf;
	
	// set fields type and change labels
	For Counter = 1 To MaxExtraDimension Do
		
		If Not ValueIsFilled(Account) Or Counter > Account.ExtDimensionTypes.Count() Then
			
			If ValueIsFilled(Object[ExtDimensionName + Counter]) Then
				Object[ExtDimensionName + Counter] = Undefined;
			EndIf;
			
		Else
			ExtDimensionType = Account.ExtDimensionTypes[Counter-1].ExtDimensionType;
			ExtDimensionTypesDescription = ExtDimensionType.ValueType;
			Object[ExtDimensionName + Counter] = ExtDimensionTypesDescription.AdjustValue(Object[ExtDimensionName + Counter]);
			
		EndIf;
		
	EndDo;
	
EndProcedure



Function GetBookkeepingOperation(DocumentRef) Export 
	Answer = New Structure("Success,Message,ShowMessage,BookkeepingOperation,Empty",False,"",False,Undefined,False);
	BookkeepingIsRegisterRecords = FALSE;
	
	MetadataDocument = Metadata.Documents[DocumentRef.Metadata().Name];
	
	For each RegisterRecords in MetadataDocument.RegisterRecords do
		If Metadata.AccountingRegisters.Bookkeeping = RegisterRecords Then
			BookkeepingIsRegisterRecords = TRUE;
			Break;
		EndIf;

	EndDo;
	
	// If base document is BO
	If TypeOf(DocumentRef) = TypeOf(Documents.BookkeepingOperation.EmptyRef()) or BookkeepingIsRegisterRecords = TRUE   Then
		Return Answer;		
	ElsIf BookkeepingIsRegisterRecords = FALSE Then
		
		Query = New Query;
		
		Query.Text = "SELECT
		             |	BookkeepingOperation.Ref AS BookkeepingOperation
		             |FROM
		             |	Document.BookkeepingOperation AS BookkeepingOperation
		             |WHERE
		             |	BookkeepingOperation.DocumentBase = &ReportsDocument";		
		Query.SetParameter("ReportsDocument",DocumentRef);
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			// 	There is no BO
			RecordKey = InformationRegisters.BookkeepingPostingSettings.Get(New Structure("Object",New (TypeOf(DocumentRef))));
			BookkeepingPostingType = RecordKey.BookkeepingPostingType;
			If NOT DocumentRef.Posted Then
				Answer.ShowMessage = True;
				Answer.Message = NStr("en = 'This document was not posted. Unposted document could not have no bookkeeping operation.'; pl = 'Ten dokument nie został zatwierdzony. Nie zatwierdzony document nie może posiadać DK.'")
			ElsIf BookkeepingPostingType = Enums.BookkeepingPostingTypes.DontPost Then	
				Answer.ShowMessage = True;
				Answer.Message = NStr("en = 'This document could not be bookkeeping posted. Please check your bookkeeping posting settings.'; pl = 'Ten dokument nie może być zaksięgowany. Sprawdź ustawienia księgowania.'");				
			Else	
				If AccessRight("Posting",Metadata.Documents.BookkeepingOperation) Then
					Answer.Empty = True;
				Else	
					Answer.ShowMessage = True;
					Answer.Message = NStr("en = 'For this document bookkeeping operation does not exists. You don''t have enough permissions to create a new one!'; pl = 'Na podstawie tego dokumentu nie został zaksięgowany dowód księgowy. Nie masz wystarczająco uprawnień aby stworzyć lub zaksięgować nowy!'");					
				EndIf;	
			EndIf;
		Else
			// BO is found, open it
			Selection = QueryResult.Select();
			Selection.Next();
			Answer.Success = True;
			Answer.BookkeepingOperation = Selection.BookkeepingOperation;
		EndIf;	
				
	EndIf;
	
	Return Answer;
		
EndFunction


Procedure AddDocumentTabularPartCodeColumn(ThisForm) Export
	Object = ThisForm.Object;
	//  by Jack 28.03.2017
	//CodeType = CommonAtServer.GetUserSettingsValue(ChartsOfCharacteristicTypes.UserSettings.ShowItemCodeInDocument, SessionParameters.CurrentUser);
	CodeType = Enums.CodeTypes.DontShow;

	AllItems = ThisForm.Items;
	ObjectMetadata = Object.Ref.Metadata();
	ItemType = Type("CatalogRef.Items");
	If ValueIsFilled(CodeType) AND CodeType <> Enums.CodeTypes.DontShow Then
		For Each TabularPart In ObjectMetadata.TabularSections Do
			ParentItem = AllItems.Find(TabularPart.Name);			
			If ParentItem <> Undefined Then			
				For Each CurrentAttribute In TabularPart.Attributes Do							
					If CurrentAttribute.Type.ContainsType(ItemType) AND CurrentAttribute.Type.Types().Count() = 1 Then
						CodeColumn = AllItems.Insert(TabularPart.Name + "GeneratedCodeColumn", Type("FormField"), ParentItem, AllItems[TabularPart.Name + CurrentAttribute.Name]);
						AllItems.Move(AllItems[TabularPart.Name + CurrentAttribute.Name], AllItems[TabularPart.Name] , CodeColumn);
						CodeColumn.Type = FormFieldType.InputField;
						CodeColumn.ReadOnly = True;
						CodeColumn.Visible = True;
						CodeColumn.Width = 20;
						
						If CodeType = Enums.CodeTypes.Code Then				
							AttributeName = "Code";
						ElsIf CodeType = Enums.CodeTypes.Article Then
							AttributeName = "Article";
						ElsIf CodeType = Enums.CodeTypes.EANCode Then
							AttributeName = "MainBarCode";
						EndIf;
						
						CodeColumn.DataPath = "Object." + TabularPart.Name + "." + CurrentAttribute.Name + "." + AttributeName;
					EndIf;				
				EndDo;			
			EndIf; 
		EndDo;
	EndIf;
	
EndProcedure
			