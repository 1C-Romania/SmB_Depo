
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ValueTree = New ValueTree;
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	SQ = New StringQualifiers(100);
	DetailsString = New TypeDescription(TypeArray, SQ);
	ColumnsContent = ValueTree.Columns;
	
	ColumnsContent.Add("FieldDetails", 		DetailsString);
	ColumnsContent.Add("FieldPresentation", 	DetailsString);
	ColumnsContent.Add("Source", 			DetailsString);
	ColumnsContent.Add("FieldName", 				DetailsString);

 	NewSource = ValueTree.Rows.Add();
	NewSource.FieldDetails = "Accounting information";

	For Each MetadataRegistry IN Metadata.AccumulationRegisters Do

		If MetadataRegistry.Resources.Count() = 0 Then
			Continue;
		EndIf;
		
		Sources = NewSource.Rows.Add();
		Sources.Source 		= "AccumulationRegister." + MetadataRegistry.Name;
		Sources.FieldDetails 	= MetadataRegistry.Presentation();
		
		SourceTable = Sources.Rows.Add();
		SourceTable.Source 			= "AccumulationRegister." + MetadataRegistry.Name;
		SourceTable.FieldDetails 		= "RegisterRecords";
		
		If MetadataRegistry.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then
			
			SourceTableReceipt = SourceTable.Rows.Add();
			SourceTableReceipt.Source 			= "AccumulationRegister." + MetadataRegistry.Name;
			SourceTableReceipt.FieldPresentation = MetadataRegistry.Presentation() + " register records: receipt";
			SourceTableReceipt.FieldDetails 		= "register records: receipt";		
			SourceTableReceipt.FieldName 			= MetadataRegistry.Name + "RegisterRecordsReceipt";
			
			SourceTableExpense = SourceTable.Rows.Add();
			SourceTableExpense.Source 			= "AccumulationRegister." + MetadataRegistry.Name;
			SourceTableExpense.FieldPresentation	= MetadataRegistry.Presentation() + " flow: expense";
			SourceTableExpense.FieldDetails 		= "flow: expense";		
			SourceTableExpense.FieldName 			= MetadataRegistry.Name + "RegisterRecordsExpense";
			
		Else
			
			SourceTableRecord = SourceTable.Rows.Add();
			SourceTableRecord.Source 			= "AccumulationRegister." + MetadataRegistry.Name;
			SourceTableRecord.FieldPresentation 	= MetadataRegistry.Presentation() + " flow: turnover";
			SourceTableRecord.FieldDetails 		= "flow: turnover";		
			SourceTableRecord.FieldName 			= MetadataRegistry.Name + "RegisterRecordsTurnover";

		EndIf;
		
		If MetadataRegistry.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance Then

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 			= "AccumulationRegister." + MetadataRegistry.Name + ".Balance(&PointInTime,)";
			SourceTable.FieldPresentation	= MetadataRegistry.Presentation() + ": balance";
			SourceTable.FieldDetails		= "Balance";
			SourceTable.FieldName				= MetadataRegistry.Name + "Balance";

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 			= "AccumulationRegister." + MetadataRegistry.Name + ".Turnovers(&BeginOfPeriod,&EndOfPeriod,Auto,)";
			SourceTable.FieldPresentation 	= MetadataRegistry.Presentation() + ": turnovers";
			SourceTable.FieldDetails 		= "Turnovers";
			SourceTable.FieldName				= MetadataRegistry.Name+"Turnovers";

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 			= "AccumulationRegister." + MetadataRegistry.Name + ".BalanceAndTurnovers(&BeginOfPeriod,&EndOfPeriod,Auto,,)";
			SourceTable.FieldPresentation 	= MetadataRegistry.Presentation() + ": balance and turnovers";
			SourceTable.FieldDetails 		= "Balance and turnovers";
			SourceTable.FieldName				= MetadataRegistry.Name + "BalanceAndTurnovers";

		Else

			SourceTable = Sources.Rows.Add();
			SourceTable.Source 			= "AccumulationRegister." + MetadataRegistry.Name + ".Turnovers(&BeginOfPeriod,&EndOfPeriod,Auto,)";
			SourceTable.FieldPresentation 	= MetadataRegistry.Presentation() + ": turnovers";
			SourceTable.FieldDetails 		= "Turnovers";
			SourceTable.FieldName 			= MetadataRegistry.Name + "Turnovers";

		EndIf;

	EndDo;

	NewSource = ValueTree.Rows.Add();
	NewSource.FieldDetails = "Help information";

	For Each MetadataRegistry IN Metadata.InformationRegisters Do

		NumberResource = 0;

		For Each Resource IN MetadataRegistry.Resources Do	

			ResourceTypes = Resource.Type.Types();

			If ResourceTypes.Count() = 1 AND ResourceTypes[0] = Type("Number") Then
				NumberResource = NumberResource + 1;
			EndIf;
		
		EndDo; 
		
		If NumberResource = 0 Then
			Continue;
		EndIf;

		Sources = NewSource.Rows.Add();

		If String(MetadataRegistry.InformationRegisterPeriodicity) = "Nonperiodical" Then
			Sources.Source = "InformationRegister." + MetadataRegistry.Name;
		Else
			Sources.Source = "InformationRegister." + MetadataRegistry.Name + ".SliceLast(&PointInTime,)";
		EndIf;
		
		Sources.FieldPresentation = MetadataRegistry.Presentation();
		Sources.FieldDetails 		= MetadataRegistry.Presentation();
		Sources.FieldName 			= MetadataRegistry.Name;

	EndDo;	
	
	NewSource = ValueTree.Rows.Add();
	NewSource.FieldDetails = "Balance and turnovers according to the char of accounts";

	For Each MetadataRegistry IN Metadata.AccountingRegisters Do

		If MetadataRegistry.Resources.Count()=0 Then
			
			Continue;
			
		EndIf;

		SourceRegister	= NewSource.Rows.Add();
		SourceRegister.Source = "AccountingRegister." + MetadataRegistry.Name;
		SourceRegister.FieldDetails = MetadataRegistry.Presentation();

		SourceRegisterTable = SourceRegister.Rows.Add();
		SourceRegisterTable.Source = "AccountingRegister." + MetadataRegistry.Name + ".Turnovers(&BeginOfPeriod,&EndOfPeriod,Day,,)";
		SourceRegisterTable.FieldPresentation = MetadataRegistry.Presentation() + ": turnovers";
		SourceRegisterTable.FieldDetails = "Turnovers";
		SourceRegisterTable.FieldName = MetadataRegistry.Name + "Turnovers";
		
		SourceRegisterTable = SourceRegister.Rows.Add();
		SourceRegisterTable.Source = "AccountingRegister." + MetadataRegistry.Name + ".Balance(&PointInTime,,) ";
		SourceRegisterTable.FieldPresentation = MetadataRegistry.Presentation() + ": balance";
		SourceRegisterTable.FieldDetails = "Balance";
		SourceRegisterTable.FieldName = MetadataRegistry.Name + "Balance";

		SourceRegisterTable = SourceRegister.Rows.Add();
		SourceRegisterTable.Source = "AccountingRegister." + MetadataRegistry.Name + ".BalanceAndTurnovers(&BeginOfPeriod,&EndOfPeriod,Day,,) ";
		SourceRegisterTable.FieldPresentation = MetadataRegistry.Presentation() + ": balance and turnovers";
		SourceRegisterTable.FieldDetails = "Balance and turnovers";
		SourceRegisterTable.FieldName = MetadataRegistry.Name + "BalanceAndTurnovers";

	EndDo;
	
	ThisForm.ValueToFormAttribute(ValueTree, "Source");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// OnOpen event handler procedure of the form.
//
Procedure SourceSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If IsBlankString(Item.CurrentData.FieldPresentation) Then
		Return;
	EndIf;	
	
	ChoiceStructure = New Structure;
	ChoiceStructure.Insert("Source", 			Item.CurrentData.Source);
	ChoiceStructure.Insert("FieldDetails", 		Item.CurrentData.FieldDetails);
	ChoiceStructure.Insert("FieldName", 			Item.CurrentData.FieldName);
	ChoiceStructure.Insert("FieldPresentation", 	Item.CurrentData.FieldPresentation);
  
	Close(ChoiceStructure);
	
EndProcedure // SourceSelection()


















