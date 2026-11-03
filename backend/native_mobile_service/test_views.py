"""Test-only DRF exercising the production-shaped authentication boundary.

No operational module imports these views or this URLConf. A response cannot
use an ambient Django web session and never contains customer PII.
"""
from django.http import Http404
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from reminders.models import WorkspaceMember
from reminders.views import _visible_renewals
from .authentication import CandidateMobileBearerAuthentication


class CandidateReadOnly(APIView):
    authentication_classes = [CandidateMobileBearerAuthentication]
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "head", "options"]

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store, max-age=0"
        response["Pragma"] = "no-cache"
        return response


class CandidateMobileMe(CandidateReadOnly):
    def get(self, request):
        if request.query_params:
            return Response({"error": "invalid_request"}, status=400)
        return Response({"authenticated": True, "user_id": request.user.pk})


class CandidateWorkspaceRenewals(CandidateReadOnly):
    def get(self, request, workspace_id):
        if request.query_params:
            return Response({"error": "invalid_request"}, status=400)
        member = WorkspaceMember.objects.filter(
            user_id=request.user.pk, workspace_id=workspace_id,
        ).first()
        if member is None:
            raise Http404()
        queryset = _visible_renewals(member).order_by("expires_on", "id")
        results = list(queryset.values("id", "expires_on", "status")[:50])
        return Response({
            "workspace_id": str(workspace_id),
            "results": [{
                "id": str(row["id"]),
                "expires_on": row["expires_on"].isoformat(),
                "status": row["status"],
            } for row in results],
        })
