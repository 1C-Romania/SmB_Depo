#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)

	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.WorkOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
   
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Event") Then
	
		Event = FillingData.Ref;
		If FillingData.Parties.Count() > 0 Then
			NewRow = Works.Add();
			NewRow.Customer = FillingData.Parties[0].Contact;
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND (FillingData.OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale
		OR FillingData.OperationKind = Enums.OperationKindsCustomerOrder.OrderForProcessing) Then	
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CustomerOrder.Company AS Company,
		|	CustomerOrder.PriceKind AS PriceKind,
		|	CustomerOrder.SalesStructuralUnit AS StructuralUnit,
		|	CustomerOrder.Inventory.(
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		ShipmentDate AS Day,
		|		Price AS Price,
		|		Amount AS Amount,
		|		Ref AS Customer
		|	)
		|FROM
		|	Document.CustomerOrder AS CustomerOrder
		|WHERE
		|	CustomerOrder.Ref = &BasisDocument
		|	AND (CustomerOrder.Inventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
		|			OR CustomerOrder.Inventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Work))";
		
		Query.SetParameter("BasisDocument", FillingData);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			Works.Load(QueryResultSelection.Inventory.Unload());
			
		Else
			
			NewRow = Works.Add();
			NewRow.Customer = FillingData;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND FillingData.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	CustomerOrder.Company AS Company,
		|	CustomerOrder.PriceKind AS PriceKind,
		|	CustomerOrder.SalesStructuralUnit AS StructuralUnit,
		|	CustomerOrder.WorkKind AS WorkKind,
		|	CustomerOrder.Finish AS Finish,
		|	CustomerOrder.Start AS Start,
		|	CustomerOrder.Ref AS Customer,
		|	CustomerOrder.Works.(
		|		Ref AS Customer,
		|		ProductsAndServices AS ProductsAndServices,
		|		Characteristic AS Characteristic,
		|		WorkKind AS WorkKind,
		|		Price AS Price,
		|		Amount AS Amount,
		|		Quantity AS Quantity,
		|		Multiplicity AS Multiplicity,
		|		Factor AS Factor
		|	)
		|FROM
		|	Document.CustomerOrder AS CustomerOrder
		|WHERE
		|	CustomerOrder.Ref = &BasisDocument";
		
		Query.SetParameter("BasisDocument", FillingData);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			FillPropertyValues(ThisObject, QueryResultSelection);
			
			TableWorks = QueryResultSelection.Works.Unload();
			For Each WorkRow in TableWorks Do
				
				NewRow = Works.Add();
				FillPropertyValues(NewRow, WorkRow);
				NewRow.Day = QueryResultSelection.Start;
				
				NewRow.DurationInHours = WorkRow.Quantity * WorkRow.Multiplicity * WorkRow.Factor;
				If NewRow.DurationInHours >= 24 Then
					
					NewRow.DurationInHours = (EndOfDay(QueryResultSelection.Start) - QueryResultSelection.Start) / 3600;
					
				EndIf;
				
				DurationInSeconds = NewRow.DurationInHours * 3600 - ?(NewRow.DurationInHours = 24, 1, 0);
				Hours = Int(DurationInSeconds / 3600);
				Minutes = (DurationInSeconds - Hours * 3600) / 60;
				NewRow.Duration = Date(0001, 01, 01, Hours, Minutes, 0);
				
				Start = Date(0001, 01, 01, Hour(QueryResultSelection.Start), Minute(QueryResultSelection.Start), 0);
				NewRow.BeginTime = Start;
				NewRow.EndTime = Start + NewRow.DurationInHours * 3600;
				
			EndDo;
			
			If Works.Count() = 0 Then
				NewRow = Works.Add();
				NewRow.Customer = QueryResultSelection.Customer;
			EndIf;
			
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then

		FillPropertyValues(ThisObject, FillingData);
		
		If FillingData.Property("Works") Then	
			For Each WorkRow IN FillingData.Works Do
				NewRow = Works.Add();
				FillPropertyValues(NewRow, WorkRow);
			EndDo;
		EndIf;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
If DataExchange.Load Then
		Return;
	EndIf;

	If WorkKindPosition = Enums.AttributePositionOnForm.InHeader Then
		For Each TabularSectionRow IN Works Do
			TabularSectionRow.WorkKind = WorkKind;
		EndDo;
	EndIf;
			
	DocumentAmount = Works.Total("Amount");
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If DataExchange.Load Then
		Return;
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)

	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf