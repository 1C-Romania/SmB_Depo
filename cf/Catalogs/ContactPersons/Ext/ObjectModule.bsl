#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		CounterpartyAttributes = CommonUse.ObjectAttributesValues(FillingData, "IsFolder,Responsible");
		
		If Not CounterpartyAttributes.IsFolder Then
			Owner		= FillingData;
			Responsible	= CounterpartyAttributes.Responsible;
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		CreationDate = CurrentSessionDate();
	EndIf;
	
	RolesList = "";
	For Each RoleTP In Roles Do
		RolesList = RolesList + ?(RolesList = "","",", ") + RoleTP.Role;
	EndDo;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ClearAttributeMainContactPerson();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillByDefault()
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
	CreationDate = CurrentSessionDate();
	
EndProcedure

Procedure ClearAttributeMainContactPerson()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Counterparties.Ref AS Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.ContactPerson = &ContactPerson";
	
	Query.SetParameter("ContactPerson", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.ContactPerson = Undefined;
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf