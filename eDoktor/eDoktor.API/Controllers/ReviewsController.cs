using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Reviews;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace eDoktor.API.Controllers
{
    [ApiController, Route("api/reviews"), Authorize]
    public class ReviewsController : ControllerBase
    {
        private readonly IReviewService _reviews;
        private readonly ICurrentUserService _current;
        public ReviewsController(IReviewService r, ICurrentUserService c) { _reviews = r; _current = c; }

        [HttpGet]
        public Task<PagedResult<ReviewResponse>> Get([FromQuery] ReviewSearchObject s) => _reviews.GetAsync(s ?? new());

        [HttpGet("{id}")]
        public Task<ReviewResponse> GetById(int id) => _reviews.GetByIdAsync(id);

        [HttpPut("{id}"), Authorize(Roles = Roles.Patient)]
        public async Task<ReviewResponse> Update(int id, ReviewUpsertRequest req)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            return await _reviews.UpdateAsync(id, req, uid);
        }

        [HttpPost]
        public async Task<ReviewResponse> Create(ReviewUpsertRequest req)
        {
            var uid = await _current.GetUserIdAsync() ?? throw new UserException("Niste prijavljeni.");
            return await _reviews.CreateAsync(req, uid);
        }

        [HttpDelete("{id}"), Authorize(Roles = Roles.Admin)]
        public Task<bool> Delete(int id) => _reviews.DeleteAsync(id);
    }
}
