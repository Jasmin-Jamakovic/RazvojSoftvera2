using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using System.Text.Encodings.Web;

namespace eDoktor.API.Filters
{
    public class ExceptionFilter : ExceptionFilterAttribute
    {
         private readonly ILogger<ExceptionFilter> _logger;
        public ExceptionFilter(ILogger<ExceptionFilter> logger){
                _logger = logger;
        }
        public override void OnException(ExceptionContext context)
        {
            _logger.LogError(context.Exception, context.Exception.Message);
            
            if(context.Exception is UserException){
                context.ModelState.AddModelError("userError", context.Exception.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.BadRequest;
            }
            else if(context.Exception is ForbiddenException){
                context.ModelState.AddModelError("userError", context.Exception.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.Forbidden;
            }
            else if(context.Exception is NotFoundException){
                context.ModelState.AddModelError("userError", context.Exception.Message);
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.NotFound;
            }
            else{
                context.ModelState.AddModelError("Error", "Server side error occured");
                context.HttpContext.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
            }
            var list = context.ModelState.Where(x => x.Value.Errors.Count > 0)
                .ToDictionary(x => x.Key, y => y.Value.Errors.Select(z => z.ErrorMessage));

            context.Result = new JsonResult(new {
                errors = list
            });
        }
    }
}
